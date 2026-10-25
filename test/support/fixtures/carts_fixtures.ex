defmodule Harbor.CartsFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Harbor.Carts`
  context.
  """
  alias Harbor.Carts

  def cart_fixture(scope, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{})

    {:ok, cart} =
      scope
      |> Carts.create_cart(attrs)

    cart
  end

  def cart_item_fixture(cart, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{quantity: 42})
    {:ok, cart_item} = Carts.create_cart_item(cart, attrs)

    cart_item
  end
end
