defmodule Harbor.Customers.Customer do
  @moduledoc """
  Ecto schema that stores shopper contact details for both guests and
  authenticated users.

  Each customer may be linked to a [User](`Harbor.Accounts.User`) via `user_id`,
  enabling a one-to-one relationship between store accounts and storefront
  profiles. Guest checkouts create customer records without a user association
  and later attach them when the shopper registers or signs in.
  """
  use Harbor.Schema

  alias Harbor.Authorization
  alias Harbor.Billing

  @type t() :: %__MODULE__{}

  schema "customers" do
    field :first_name, :string
    field :last_name, :string
    field :company_name, :string
    field :email, :string
    field :phone, :string
    field :status, Ecto.Enum, values: [:active, :blocked], default: :active
    field :default_shipping_address_id, :id
    field :user_id, :binary_id
    field :deleted_at, :utc_datetime_usec

    timestamps()
  end

  @doc false
  def changeset(customer, attrs, scope) do
    customer
    |> cast(attrs, allowed_fields(scope))
    |> validate_email()
    |> sync_email_changes()
    |> unique_constraint(:user_id)
  end

  defp sync_email_changes(changeset) do
    id = get_field(changeset, :id)

    if changed?(changeset, :email) && id do
      prepare_changes(changeset, fn prepared_changeset ->
        Billing.enqueue_payment_profile_email_sync(id)

        prepared_changeset
      end)
    else
      changeset
    end
  end

  @fields [:first_name, :last_name, :company_name, :phone]
  defp allowed_fields(%Scope{} = scope) do
    cond do
      Authorization.admin?(scope) ->
        [:email, :user_id, :deleted_at, :status | @fields]

      # Users cannot edit the email on their Customer record, since this is done
      # on their User account.
      scope.role == :user ->
        @fields

      scope.role == :guest ->
        [:email | @fields]
    end
  end
end
