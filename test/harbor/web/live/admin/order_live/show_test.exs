defmodule Harbor.Web.Admin.OrderLive.ShowTest do
  use Harbor.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.OrdersFixtures

  setup :register_and_log_in_admin

  setup %{scope: scope} do
    order = order_fixture(scope)

    %{order: order}
  end

  test "displays order", %{conn: conn, order: order} do
    {:ok, _show_live, html} = live(conn, "/admin/orders/#{order.id}")

    assert html =~ order.number
    assert html =~ "Pending"
  end

  test "transitions from pending to paid", %{conn: conn, order: order} do
    {:ok, show_live, _html} = live(conn, "/admin/orders/#{order.id}")

    assert has_element?(show_live, "button", "Mark as Paid")

    show_live
    |> element("button", "Mark as Paid")
    |> render_click()

    assert render(show_live) =~ "Order updated to paid"
    assert render(show_live) =~ "Paid"
  end

  test "transitions from paid to shipped", %{conn: conn, scope: scope} do
    order = order_fixture(scope, %{status: :paid})
    {:ok, show_live, _html} = live(conn, "/admin/orders/#{order.id}")

    assert has_element?(show_live, "button", "Mark as Shipped")

    show_live
    |> element("button", "Mark as Shipped")
    |> render_click()

    assert render(show_live) =~ "Order updated to shipped"
  end

  test "transitions from shipped to delivered", %{conn: conn, scope: scope} do
    order = order_fixture(scope, %{status: :shipped})
    {:ok, show_live, _html} = live(conn, "/admin/orders/#{order.id}")

    assert has_element?(show_live, "button", "Mark as Delivered")

    show_live
    |> element("button", "Mark as Delivered")
    |> render_click()

    assert render(show_live) =~ "Order updated to delivered"
  end

  test "can cancel a pending order", %{conn: conn, order: order} do
    {:ok, show_live, _html} = live(conn, "/admin/orders/#{order.id}")

    assert has_element?(show_live, "button", "Cancel Order")

    show_live
    |> element("button", "Cancel Order")
    |> render_click()

    assert render(show_live) =~ "Order updated to canceled"
  end

  test "navigates to edit page", %{conn: conn, order: order} do
    {:ok, show_live, _html} = live(conn, "/admin/orders/#{order.id}")

    assert {:ok, _form_live, html} =
             show_live
             |> element("a", "Edit")
             |> render_click()
             |> follow_redirect(conn, "/admin/orders/#{order.id}/edit?return_to=show")

    assert html =~ "Edit Order"
  end
end
