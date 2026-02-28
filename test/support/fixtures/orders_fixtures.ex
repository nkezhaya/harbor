defmodule Harbor.OrdersFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Harbor.Orders` context.
  """
  alias Harbor.Orders

  def order_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        email: "order@example.com",
        delivery_method_name: "Local Pickup",
        subtotal: Money.new(:USD, 10),
        tax: Money.new(:USD, 0),
        shipping_price: Money.new(:USD, 0),
        status: :pending
      })

    {:ok, order} = Orders.create_order(scope, attrs)

    order
  end
end
