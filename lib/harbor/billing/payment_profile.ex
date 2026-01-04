defmodule Harbor.Billing.PaymentProfile do
  @moduledoc """
  Ecto schema representing the stored payment profile for a customer, mapped to
  the provider.
  """
  use Harbor.Schema

  alias Harbor.Accounts.Scope
  alias Harbor.Billing.PaymentMethod
  alias Harbor.Customers.Customer

  @type t() :: %__MODULE__{}

  schema "payment_profiles" do
    field :provider, :string
    field :provider_ref, :string

    belongs_to :customer, Customer
    has_many :payment_methods, PaymentMethod

    timestamps()
  end

  @doc false
  def changeset(profile, attrs, scope) do
    profile
    |> cast(attrs, [:provider_ref])
    |> validate_required([:provider, :provider_ref])
    |> apply_scope(scope)
    |> unique_constraint([:provider, :customer_id], error_key: :customer_id)
    |> unique_constraint([:provider, :provider_ref], error_key: :provider_ref)
  end

  defp apply_scope(changeset, %Scope{customer: %Customer{} = customer}) do
    change(changeset, %{customer_id: customer.id})
  end
end
