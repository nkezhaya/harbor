defmodule Harbor.Web.OrderLive.IndexTest do
  use Harbor.ConnCase, async: true

  import Harbor.{AccountsFixtures, CustomersFixtures, OrdersFixtures}
  import Phoenix.LiveViewTest

  alias Harbor.Accounts.Scope

  test "redirects guests to login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, "/orders")
  end

  test "renders only the current customer's orders", %{conn: conn} do
    user = user_fixture()
    scope = Scope.for_user(user)
    customer_fixture(scope, %{email: user.email})
    scope = Scope.for_user(user)
    own_order = order_fixture(scope)

    other_scope = user_scope_fixture()
    customer_fixture(other_scope, %{email: other_scope.user.email})
    other_scope = Scope.for_user(other_scope.user)
    other_order = order_fixture(other_scope)

    {:ok, view, _html} = live(log_in_user(conn, user), "/orders")

    assert has_element?(view, "#orders-#{own_order.id}")
    refute has_element?(view, "#orders-#{other_order.id}")
  end

  test "renders only the admin's customer orders on the storefront", %{conn: conn} do
    admin = admin_fixture()
    scope = Scope.for_user(admin)
    customer_fixture(scope, %{email: admin.email})
    scope = Scope.for_user(admin)
    own_order = order_fixture(scope, %{customer_id: scope.customer.id})
    other_order = order_fixture(Scope.for_system())

    {:ok, view, _html} = live(log_in_user(conn, admin), "/orders")

    assert has_element?(view, "#orders-#{own_order.id}")
    refute has_element?(view, "#orders-#{other_order.id}")
  end

  test "renders an empty index for authenticated users without a customer", %{conn: conn} do
    foreign_order = order_fixture(Scope.for_system())
    user = user_fixture()
    admin = admin_fixture()

    {:ok, user_view, _html} = live(log_in_user(conn, user), "/orders")
    {:ok, admin_view, _html} = live(log_in_user(conn, admin), "/orders")

    refute has_element?(user_view, "#orders-#{foreign_order.id}")
    refute has_element?(admin_view, "#orders-#{foreign_order.id}")
  end
end
