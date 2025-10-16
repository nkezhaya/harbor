defmodule Harbor.Checkout.CartItem do
  @moduledoc """
  Ecto schema for items within a shopping cart.
  """
  use Harbor.Schema

  alias Harbor.Catalog.Variant
  alias Harbor.Checkout.Cart

  @type t() :: %__MODULE__{}

  schema "cart_items" do
    field :quantity, :integer, default: 1

    belongs_to :cart, Cart
    belongs_to :variant, Variant

    timestamps()
  end

  @doc false
  def changeset(cart_item, attrs) do
    cart_item
    |> cast(attrs, [:quantity, :variant_id])
    |> validate_required([:quantity, :variant_id])
    |> check_constraint(:quantity, name: :quantity_gte_zero, message: "must be greater than 0")
  end
end
