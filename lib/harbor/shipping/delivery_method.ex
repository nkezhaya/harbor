defmodule Harbor.Shipping.DeliveryMethod do
  @moduledoc """
  Ecto schema for delivery/shipping methods.
  """
  use Harbor.Schema
  import Money.Validate, only: [validate_money: 3]

  @type t() :: %__MODULE__{}

  schema "delivery_methods" do
    field :name, :string
    field :price, Money.Ecto.Composite.Type
    field :fulfillment_type, Ecto.Enum, values: [:ship, :pickup]

    timestamps()
  end

  @doc false
  def changeset(delivery_method, attrs) do
    delivery_method
    |> cast(attrs, [:name, :price, :fulfillment_type])
    |> validate_required([:name, :price, :fulfillment_type])
    |> validate_price()
    |> unique_constraint(:name)
  end

  defp validate_price(changeset) do
    case fetch_change(changeset, :price) do
      {:ok, %Money{} = money} ->
        validate_money(changeset, :price, greater_than_or_equal_to: Money.zero(money.currency))

      _ ->
        changeset
    end
  end
end
