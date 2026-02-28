defmodule Harbor.OrdersTest do
  use Harbor.DataCase, async: true
  import Harbor.OrdersFixtures

  alias Harbor.Accounts.Scope
  alias Harbor.Orders
  alias Harbor.Orders.Order

  setup do
    [scope: Scope.for_system()]
  end

  describe "get_order!/2" do
    test "returns the order with given id", %{scope: scope} do
      order = order_fixture(scope)
      fetched = Orders.get_order!(scope, order.id)
      assert fetched.id == order.id
    end
  end

  describe "create_order/2" do
    test "with valid data creates an order", %{scope: scope} do
      valid_attrs = %{
        email: "user@example.com",
        delivery_method_name: "Local Pickup",
        subtotal: Money.new(:USD, "0.42"),
        shipping_price: Money.new(:USD, "0.10"),
        tax: Money.new(:USD, 0)
      }

      assert {:ok, %Order{} = order} = Orders.create_order(scope, valid_attrs)
      assert Money.equal?(order.shipping_price, Money.new(:USD, "0.10"))
      assert Money.equal?(order.total_price, Money.new(:USD, "0.52"))
    end

    test "with invalid data returns error changeset", %{scope: scope} do
      assert {:error, %Ecto.Changeset{}} =
               Orders.create_order(scope, %{shipping_price: nil})
    end
  end

  describe "update_order/3" do
    test "with valid data updates the order", %{scope: scope} do
      order = order_fixture(scope)
      update_attrs = %{email: "new@example.com"}

      assert {:ok, %Order{} = order} = Orders.update_order(scope, order, update_attrs)
      assert order.email == "new@example.com"
    end

    test "with invalid data returns error changeset", %{scope: scope} do
      order = order_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Orders.update_order(scope, order, %{shipping_price: nil})

      assert Orders.get_order!(scope, order.id).email == order.email
    end
  end

  describe "delete_order/2" do
    test "deletes the order", %{scope: scope} do
      order = order_fixture(scope)
      assert {:ok, %Order{}} = Orders.delete_order(scope, order)
      assert_raise Ecto.NoResultsError, fn -> Orders.get_order!(scope, order.id) end
    end
  end

  describe "change_order/2" do
    test "returns an order changeset", %{scope: scope} do
      order = order_fixture(scope)
      assert %Ecto.Changeset{} = Orders.change_order(scope, order)
    end
  end
end
