defmodule Harbor.Web.Admin.OrderLive.IndexTest do
  use Harbor.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.OrdersFixtures

  setup :register_and_log_in_admin

  setup %{scope: scope} do
    order = order_fixture(scope)

    %{order: order}
  end

  test "lists all orders", %{conn: conn, order: order} do
    {:ok, _index_live, html} = live(conn, "/admin/orders")

    assert html =~ "Listing Orders"
    assert html =~ order.number
  end

  test "navigates to show page", %{conn: conn, order: order} do
    {:ok, index_live, _html} = live(conn, "/admin/orders")

    assert {:ok, _show_live, html} =
             index_live
             |> element("#orders-#{order.id}")
             |> render_click()
             |> follow_redirect(conn, "/admin/orders/#{order.id}")

    assert html =~ order.number
  end

  test "navigates to new order form", %{conn: conn} do
    {:ok, index_live, _html} = live(conn, "/admin/orders")

    assert {:ok, _form_live, html} =
             index_live
             |> element("a", "New Order")
             |> render_click()
             |> follow_redirect(conn, "/admin/orders/new")

    assert html =~ "New Order"
  end

  test "filters orders by status", %{conn: conn, order: order} do
    {:ok, index_live, _html} = live(conn, "/admin/orders?status=pending")

    assert has_element?(index_live, "#orders-#{order.id}")

    {:ok, index_live, _html} = live(conn, "/admin/orders?status=shipped")

    refute has_element?(index_live, "#orders-#{order.id}")
  end
end
