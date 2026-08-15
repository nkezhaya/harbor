defmodule Harbor.OrdersTest do
  use Harbor.DataCase, async: true
  import Harbor.{AccountsFixtures, CustomersFixtures, OrdersFixtures}

  alias Harbor.Accounts.Scope
  alias Harbor.Orders
  alias Harbor.Orders.Order

  setup do
    [scope: Scope.for_system()]
  end

  describe "list_orders/2" do
    test "returns no orders for guests and authenticated scopes without a customer", %{
      scope: scope
    } do
      customer = customer_fixture(scope)
      order_fixture(scope, %{customer_id: customer.id})

      guest_scope = Scope.for_guest() |> Scope.attach_customer(customer)
      assert Orders.list_orders(guest_scope, %{}) == []
      assert Orders.list_orders(guest_scope, %{"customer_id" => customer.id}) == []

      user_scope = user_scope_fixture()
      assert Orders.list_orders(user_scope, %{}) == []
      assert Orders.list_orders(user_scope, %{"customer_id" => customer.id}) == []
    end

    test "restricts customers to their own orders" do
      first_scope = user_scope_fixture()
      customer_fixture(first_scope, %{email: first_scope.user.email})
      first_scope = Scope.for_user(first_scope.user)

      second_scope = user_scope_fixture()
      customer_fixture(second_scope, %{email: second_scope.user.email})
      second_scope = Scope.for_user(second_scope.user)

      first_order = order_fixture(first_scope)
      order_fixture(second_scope)

      assert [%Order{id: order_id}] = Orders.list_orders(first_scope, %{})
      assert order_id == first_order.id

      assert [%Order{id: order_id}] =
               Orders.list_orders(first_scope, %{"customer_id" => second_scope.customer.id})

      assert order_id == first_order.id
    end

    test "preserves unrestricted admin access and optional customer constraints" do
      admin_scope = admin_scope_fixture()
      first_customer = customer_fixture(admin_scope)
      second_customer = customer_fixture(admin_scope, %{email: unique_user_email()})
      first_order = order_fixture(admin_scope, %{customer_id: first_customer.id})
      second_order = order_fixture(admin_scope, %{customer_id: second_customer.id})

      assert MapSet.new(Orders.list_orders(admin_scope, %{}), & &1.id) ==
               MapSet.new([first_order.id, second_order.id])

      assert [%Order{id: order_id}] =
               Orders.list_orders(admin_scope, %{"customer_id" => first_customer.id})

      assert order_id == first_order.id

      assert [%Order{id: order_id}] =
               Orders.list_orders(admin_scope, %{}, customer_id: second_customer.id)

      assert order_id == second_order.id
      assert Orders.list_orders(admin_scope, %{}, customer_id: nil) == []
    end
  end

  describe "get_order!/2" do
    test "returns the order with given id", %{scope: scope} do
      order = order_fixture(scope)
      fetched = Orders.get_order!(scope, order.id)
      assert fetched.id == order.id
    end

    test "denies other customers and authenticated users without a customer" do
      owner_scope = user_scope_fixture()
      customer_fixture(owner_scope, %{email: owner_scope.user.email})
      owner_scope = Scope.for_user(owner_scope.user)
      order = order_fixture(owner_scope)

      assert Orders.get_order!(owner_scope, order.id).id == order.id

      other_scope = user_scope_fixture()
      customer_fixture(other_scope, %{email: other_scope.user.email})
      other_scope = Scope.for_user(other_scope.user)

      assert_raise Harbor.UnauthorizedError, fn -> Orders.get_order!(other_scope, order.id) end

      assert_raise Harbor.UnauthorizedError, fn ->
        Orders.get_order!(user_scope_fixture(), order.id)
      end
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
