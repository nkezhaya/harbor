defmodule Harbor.OrdersTest do
  use Harbor.DataCase, async: true
  import Harbor.{CatalogFixtures, OrdersFixtures}

  alias Harbor.Orders
  alias Harbor.Orders.Order

  setup do
    variant = variant_fixture()

    [variant: variant]
  end

  describe "list_orders/0" do
    test "returns all orders" do
      order = order_fixture()
      assert Orders.list_orders() == [order]
    end
  end

  describe "get_order!/1" do
    test "returns the order with given id" do
      order = order_fixture()
      assert Orders.get_order!(order.id) == order
    end
  end

  describe "create_order/1" do
    test "with valid data creates an order" do
      valid_attrs = %{
        email: "user@example.com",
        delivery_method_name: "Local Pickup",
        subtotal: 42,
        shipping_price: 10
      }

      assert {:ok, %Order{} = order} = Orders.create_order(valid_attrs)
      assert order.shipping_price == 10
      assert order.total_price == 52
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Orders.create_order(%{shipping_price: nil, total_price: nil})
    end
  end

  describe "update_order/2" do
    test "with valid data updates the order" do
      order = order_fixture()
      update_attrs = %{email: "new@example.com"}

      assert {:ok, %Order{} = order} = Orders.update_order(order, update_attrs)
      assert order.email == "new@example.com"
    end

    test "with invalid data returns error changeset" do
      order = order_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Orders.update_order(order, %{shipping_price: nil, total_price: nil})

      assert order == Orders.get_order!(order.id)
    end
  end

  describe "delete_order/1" do
    test "deletes the order" do
      order = order_fixture()
      assert {:ok, %Order{}} = Orders.delete_order(order)
      assert_raise Ecto.NoResultsError, fn -> Orders.get_order!(order.id) end
    end
  end

  describe "change_order/1" do
    test "returns an order changeset" do
      order = order_fixture()
      assert %Ecto.Changeset{} = Orders.change_order(order)
    end
  end
end
