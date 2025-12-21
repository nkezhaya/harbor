defmodule Harbor.OrdersFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Harbor.Orders` context.
  """
  alias Harbor.Accounts.Scope
  alias Harbor.Orders

  def order_fixture(attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        email: "user@example.com",
        delivery_method_name: "Local Pickup",
        subtotal: 42,
        shipping_price: 0
      })

    scope = Scope.for_system()
    {:ok, order} = Orders.create_order(scope, attrs)

    order
  end
end
