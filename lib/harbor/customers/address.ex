defmodule Harbor.Customers.Address do
  @moduledoc """
  Ecto schema for user addresses and related validations.
  """
  use Harbor.Schema

  alias AddressInput.Country
  alias Harbor.Accounts.Scope
  alias Harbor.Customers.Customer

  @type t() :: %__MODULE__{}

  schema "addresses" do
    field :first_name, :string
    field :last_name, :string
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

  @fields [
    :first_name,
    :last_name,
    :line1,
    :line2,
    :city,
    :region,
    :postal_code,
    :country,
    :phone
  ]

  @doc false
  def changeset(address, attrs, scope \\ nil) do
    address
    |> cast(attrs, allowed_fields(scope))
    |> trim_fields(@fields)
    |> validate_required([:country, :phone])
    |> validate_country_required_fields()
    |> apply_scope(scope)
  end

  defp allowed_fields(%Scope{role: role}) when role in [:superadmin, :system] do
    [:customer_id | @fields]
  end

  defp allowed_fields(%Scope{}), do: @fields
  defp allowed_fields(nil), do: @fields

  defp apply_scope(changeset, %Scope{customer: %Customer{} = customer}) do
    change(changeset, %{customer_id: customer.id})
  end

  defp apply_scope(changeset, _scope), do: changeset

  defp validate_country_required_fields(%{valid?: true} = changeset) do
    country = get_field(changeset, :country)

    case AddressInput.get_country(country) do
      %Country{} = country ->
        required_fields = required_fields_for_country(country)

        changeset
        |> validate_required(required_fields)
        |> validate_region(country)

      _ ->
        add_error(changeset, :country, "is invalid")
    end
  end

  defp validate_country_required_fields(changeset) do
    changeset
  end

  defp validate_region(changeset, %Country{subregions: regions}) do
    case get_field(changeset, :region) do
      nil ->
        changeset

      region ->
        if Enum.any?(regions, &(&1.id == region)) do
          changeset
        else
          add_error(changeset, :region, "is invalid")
        end
    end
  end

  defp required_fields_for_country(%Country{required_fields: required_fields}) do
    Enum.flat_map(required_fields, &required_fields_for_component/1)
  end

  defp required_fields_for_component(:name), do: [:first_name, :last_name]
  defp required_fields_for_component(:address), do: [:line1]
  defp required_fields_for_component(:sublocality), do: [:city]
  defp required_fields_for_component(:region), do: [:region]
  defp required_fields_for_component(:postal_code), do: [:postal_code]
  defp required_fields_for_component(_field), do: []
end
