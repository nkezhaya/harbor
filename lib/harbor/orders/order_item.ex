defmodule Harbor.Orders.OrderItem do
  @moduledoc """
  Ecto schema for items belonging to an order.
  """
  use Harbor.Schema

  alias Harbor.Catalog.Variant
  alias Harbor.Orders.Order

  @type t() :: %__MODULE__{}

  schema "order_items" do
    field :quantity, :integer
    field :price, :integer

    belongs_to :order, Order
    belongs_to :variant, Variant

    timestamps()
  end

  @doc false
  def changeset(order_item, attrs) do
    order_item
    |> cast(attrs, [:quantity, :price, :variant_id])
    |> validate_required([:quantity, :price, :variant_id])
    |> check_constraint(:quantity, name: :quantity_gte_zero, message: "must be greater than 0")
    |> check_constraint(:price,
      name: :price_gte_zero,
      message: "must be greater than or equal to 0"
    )
  end
end
