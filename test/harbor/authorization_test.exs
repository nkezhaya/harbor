defmodule Harbor.AuthorizationTest do
  use Harbor.DataCase, async: true

  import Harbor.AccountsFixtures
  import Harbor.CheckoutFixtures
  import Harbor.CustomersFixtures
  import Harbor.OrdersFixtures

  alias Harbor.Accounts.Scope
  alias Harbor.Authorization
  alias Harbor.Customers.Customer

  describe "ensure_admin!/1" do
    test "allows system scopes" do
      assert :ok == Authorization.ensure_admin!(Scope.for_system())
    end

    test "allows superadmin scopes" do
      scope = admin_scope_fixture()
      assert :ok == Authorization.ensure_admin!(scope)
    end

    test "raises for non-admin scopes" do
      scope = guest_scope_fixture(customer: false)

      assert_raise Harbor.UnauthorizedError, fn ->
        Authorization.ensure_admin!(scope)
      end
    end
  end

  describe "ensure_authorized!/2" do
    test "allows admin scopes to access any resource" do
      assert :ok == Authorization.ensure_authorized!(Scope.for_system(), :resource)
    end

    test "allows order access for the matching customer" do
      scope = guest_scope_fixture(customer: %{})
      order = order_fixture(Scope.for_system(), %{customer_id: scope.customer.id})

      assert :ok == Authorization.ensure_authorized!(scope, order)
    end

    test "allows cart access for matching session tokens" do
      scope = guest_scope_fixture(customer: false)
      cart = cart_fixture(scope)

      assert :ok == Authorization.ensure_authorized!(scope, cart)
    end

    test "allows customer id access for matching scope customer" do
      scope = guest_scope_fixture(customer: %{})

      assert :ok == Authorization.ensure_authorized!(scope, scope.customer.id)
    end

    test "allows customer access via matching user id" do
      user = user_fixture()
      scope = Scope.for_user(user)
      customer = %Customer{user_id: user.id}

      assert :ok == Authorization.ensure_authorized!(scope, customer)
    end

    test "raises when the scope does not own the resource" do
      scope = guest_scope_fixture(customer: %{})
      other_scope = guest_scope_fixture(customer: %{})
      order = order_fixture(Scope.for_system(), %{customer_id: other_scope.customer.id})

      assert_raise Harbor.UnauthorizedError, fn ->
        Authorization.ensure_authorized!(scope, order)
      end
    end
  end
end
