defmodule Harbor.Orders.OrderTest do
  use Harbor.DataCase, async: true
  import Harbor.OrdersFixtures
  import Harbor.ShippingFixtures

  alias Harbor.Accounts.Scope
  alias Harbor.Orders.Order

  describe "submit_changeset/3" do
    test "does not require an address for pickup fulfillment" do
      delivery_method = delivery_method_fixture(%{fulfillment_type: :pickup})
      order = order_fixture()

      order =
        order
        |> Ecto.Changeset.change(%{delivery_method_id: delivery_method.id})
        |> Repo.update!()
        |> Repo.preload([:shipping_address, :delivery_method])

      attrs = %{
        status: :pending,
        email: "pickup@example.com",
        subtotal: 100,
        tax: 0,
        shipping_price: 0
      }

      changeset = Order.submit_changeset(order, attrs, Scope.for_system())

      assert changeset.valid?
    end
  end
end
