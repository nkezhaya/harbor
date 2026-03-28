defmodule Harbor.Orders.OrderItem do
  @moduledoc """
  Ecto schema for items belonging to an order.
  """
  use Harbor.Schema
  import Money.Validate, only: [validate_money: 3]

  alias Harbor.Catalog.Variant
  alias Harbor.Orders.Order

  @type t() :: %__MODULE__{}

  schema "order_items" do
    field :quantity, :integer
    field :price, Money.Ecto.Composite.Type

    belongs_to :order, Order
    belongs_to :variant, Variant

    timestamps()
  end

  @doc false
  def changeset(order_item, attrs) do
    order_item
    |> cast(attrs, [:quantity, :price, :variant_id])
    |> validate_required([:quantity, :price, :variant_id])
    |> validate_price()
    |> check_constraint(:quantity, name: :quantity_gte_zero, message: "must be greater than 0")
    |> check_constraint(:price,
      name: :price_gte_zero,
      message: "must be greater than or equal to 0"
    )
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
