defmodule Harbor.OrdersFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Harbor.Orders` context.
  """
  alias Harbor.Orders

  def order_fixture(attrs \\ %{}) do
    {:ok, order} =
      attrs
      |> Enum.into(%{
        email: "user@example.com",
        delivery_method_name: "Local Pickup",
        subtotal: 42,
        shipping_price: 0
      })
      |> Orders.create_order()

    order
  end
end
