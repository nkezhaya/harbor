defmodule Harbor.Orders.OrderTest do
  use Harbor.DataCase, async: true
  import Harbor.CatalogFixtures
  import Harbor.OrdersFixtures
  import Harbor.ShippingFixtures

  alias Harbor.Accounts.Scope
  alias Harbor.Orders.Order

  describe "submit_changeset/4" do
    test "requires a shipping address for physical items by default" do
      scope = Scope.for_system()
      variant = variant_fixture()

      order =
        order_fixture(scope, %{
          items: [%{variant_id: variant.id, quantity: 1, price: variant.price}]
        })
        |> Repo.preload([
          :customer,
          :delivery_method,
          :shipping_address,
          items: [variant: [:product]]
        ])

      changeset = Order.submit_changeset(order, %{}, scope)

      assert errors_on(changeset).shipping_address_id == ["can't be blank"]
    end

    test "does not require an address for pickup fulfillment" do
      delivery_method = delivery_method_fixture(%{fulfillment_type: :pickup})
      scope = Scope.for_system()
      order = order_fixture(scope)

      order =
        order
        |> Order.changeset(%{delivery_method_id: delivery_method.id}, scope)
        |> Repo.update!()
        |> Repo.preload([:customer, :shipping_address, :delivery_method, :items])

      attrs = %{
        status: :pending,
        email: "pickup@example.com",
        subtotal: Money.new(:USD, 1),
        tax: Money.new(:USD, 0),
        shipping_price: Money.new(:USD, 0)
      }

      changeset = Order.submit_changeset(order, attrs, scope)

      assert changeset.valid?
    end
  end
end
