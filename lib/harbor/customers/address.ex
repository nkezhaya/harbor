defmodule Harbor.Customers.Address do
  @moduledoc """
  Ecto schema for user addresses and related validations.
  """
  use Harbor.Schema

  alias Harbor.Accounts.Scope
  alias Harbor.Customers.Customer

  @type t() :: %__MODULE__{}

  schema "addresses" do
    field :name, :string
    field :line1, :string
    field :line2, :string
    field :city, :string
    field :region, :string
    field :postal_code, :string
    field :country, :string
    field :phone, :string

    belongs_to :customer, Customer

    timestamps()
  end

  @doc false
  def changeset(address, attrs, scope \\ nil) do
    address
    |> cast(attrs, allowed_fields(scope))
    |> validate_required([:name, :line1, :city, :country, :phone])
    |> apply_scope(scope)
  end

  @fields [:name, :line1, :line2, :city, :region, :postal_code, :country, :phone]
  defp allowed_fields(%Scope{role: role}) when role in [:superadmin, :system] do
    [:customer_id | @fields]
  end

  defp allowed_fields(%Scope{}), do: @fields
  defp allowed_fields(nil), do: @fields

  defp apply_scope(changeset, %Scope{customer: %Customer{} = customer}) do
    change(changeset, %{customer_id: customer.id})
  end

  defp apply_scope(changeset, _scope), do: changeset
end
