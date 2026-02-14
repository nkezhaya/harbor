defmodule Harbor.Web.Admin.CustomerLive.ShowTest do
  use Harbor.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.CustomersFixtures

  setup :register_and_log_in_admin

  setup %{scope: scope} do
    customer = customer_fixture(scope)

    %{customer: customer}
  end

  test "displays customer", %{conn: conn, customer: customer} do
    {:ok, _show_live, html} = live(conn, "/admin/customers/#{customer.id}")

    assert html =~ "Show Customer"
    assert html =~ customer.first_name
  end

  test "updates customer and returns to show", %{conn: conn, customer: customer} do
    {:ok, show_live, _html} = live(conn, "/admin/customers/#{customer.id}")

    assert {:ok, form_live, _} =
             show_live
             |> element("a", "Edit")
             |> render_click()
             |> follow_redirect(conn, "/admin/customers/#{customer.id}/edit?return_to=show")

    assert render(form_live) =~ "Edit Customer"

    assert form_live
           |> form("#customer-form", customer: %{email: nil})
           |> render_change() =~ "can&#39;t be blank"

    assert {:ok, show_live, _html} =
             form_live
             |> form("#customer-form",
               customer: %{first_name: "New First", email: customer.email}
             )
             |> render_submit()
             |> follow_redirect(conn, "/admin/customers/#{customer.id}")

    html = render(show_live)
    assert html =~ "Customer updated successfully"
    assert html =~ "New First"
  end
end
