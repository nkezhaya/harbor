defmodule HarborWeb.Admin.CustomerLive.IndexTest do
  use HarborWeb.ConnCase

  import Phoenix.LiveViewTest
  import Harbor.CustomersFixtures

  setup :register_and_log_in_admin

  setup %{scope: scope} do
    customer = customer_fixture(scope)

    %{customer: customer}
  end

  test "lists all customers", %{conn: conn, customer: customer} do
    {:ok, _index_live, html} = live(conn, ~p"/admin/customers")

    assert html =~ "Listing Customers"
    assert html =~ customer.first_name
  end

  test "saves new customer", %{conn: conn} do
    {:ok, index_live, _html} = live(conn, ~p"/admin/customers")

    assert {:ok, form_live, _} =
             index_live
             |> element("a", "New Customer")
             |> render_click()
             |> follow_redirect(conn, ~p"/admin/customers/new")

    assert render(form_live) =~ "New Customer"

    assert form_live
           |> form("#customer-form", customer: invalid_attrs())
           |> render_change() =~ "can&#39;t be blank"

    assert {:ok, index_live, _html} =
             form_live
             |> form("#customer-form", customer: create_attrs())
             |> render_submit()
             |> follow_redirect(conn, ~p"/admin/customers")

    html = render(index_live)
    assert html =~ "Customer created successfully"
    assert html =~ "First"
  end

  test "updates customer in listing", %{conn: conn, customer: customer} do
    {:ok, index_live, _html} = live(conn, ~p"/admin/customers")

    assert {:ok, form_live, _html} =
             index_live
             |> element("#customers-#{customer.id} a", "Edit")
             |> render_click()
             |> follow_redirect(conn, ~p"/admin/customers/#{customer}/edit")

    assert render(form_live) =~ "Edit Customer"

    assert form_live
           |> form("#customer-form", customer: invalid_attrs())
           |> render_change() =~ "can&#39;t be blank"

    assert {:ok, index_live, _html} =
             form_live
             |> form("#customer-form", customer: update_attrs())
             |> render_submit()
             |> follow_redirect(conn, ~p"/admin/customers")

    html = render(index_live)
    assert html =~ "Customer updated successfully"
    assert html =~ "New First"
  end

  test "deletes customer in listing", %{conn: conn, customer: customer} do
    {:ok, index_live, _html} = live(conn, ~p"/admin/customers")

    assert index_live |> element("#customers-#{customer.id} a", "Delete") |> render_click()
    refute has_element?(index_live, "#customers-#{customer.id}")
  end

  defp create_attrs do
    %{
      status: "active",
      first_name: "First",
      last_name: "Last",
      company_name: "Company, LLC",
      email: "email@example.com",
      phone: "+13334445555"
    }
  end

  defp update_attrs do
    %{
      status: "blocked",
      first_name: "New First",
      last_name: "New Last",
      company_name: "New Company, LLC",
      email: "other.email@example.com",
      phone: "+13334445556"
    }
  end

  defp invalid_attrs do
    %{
      status: nil,
      first_name: nil,
      last_name: nil,
      company_name: nil,
      email: nil,
      phone: nil,
      deleted_at: nil
    }
  end
end
