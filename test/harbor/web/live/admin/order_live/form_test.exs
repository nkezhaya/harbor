defmodule Harbor.Web.Admin.OrderLive.FormTest do
  use Harbor.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.OrdersFixtures

  setup :register_and_log_in_admin

  setup %{scope: scope} do
    order = order_fixture(scope)

    %{order: order}
  end

  test "creates new order", %{conn: conn} do
    {:ok, form_live, _html} = live(conn, "/admin/orders/new")

    assert render(form_live) =~ "New Order"

    assert {:ok, _index_live, html} =
             form_live
             |> form("#order-form",
               order: %{
                 email: "new@example.com",
                 status: "pending"
               }
             )
             |> render_submit()
             |> follow_redirect(conn, "/admin/orders")

    assert html =~ "Order created successfully"
  end

  test "edits existing order", %{conn: conn, order: order} do
    {:ok, form_live, _html} = live(conn, "/admin/orders/#{order.id}/edit")

    assert render(form_live) =~ "Edit Order"

    assert {:ok, _index_live, html} =
             form_live
             |> form("#order-form", order: %{email: "updated@example.com", notes: "Some notes"})
             |> render_submit()
             |> follow_redirect(conn, "/admin/orders")

    assert html =~ "Order updated successfully"
  end

  test "validates on change", %{conn: conn} do
    {:ok, form_live, _html} = live(conn, "/admin/orders/new")

    html =
      form_live
      |> form("#order-form", order: %{email: "updated@example.com"})
      |> render_change()

    # Validation runs without error for valid input
    assert html =~ "updated@example.com"
  end

  test "returns to show page when return_to=show", %{conn: conn, order: order} do
    {:ok, form_live, _html} = live(conn, "/admin/orders/#{order.id}/edit?return_to=show")

    assert {:ok, _show_live, html} =
             form_live
             |> form("#order-form", order: %{notes: "Updated notes"})
             |> render_submit()
             |> follow_redirect(conn, "/admin/orders/#{order.id}")

    assert html =~ "Order updated successfully"
  end
end
