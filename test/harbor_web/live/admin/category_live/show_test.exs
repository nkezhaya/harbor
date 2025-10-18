defmodule HarborWeb.Admin.CategoryLive.ShowTest do
  use HarborWeb.ConnCase

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  setup :register_and_log_in_admin

  setup do
    category = category_fixture(%{})

    %{category: category}
  end

  test "displays category", %{conn: conn, category: category} do
    {:ok, _show_live, html} = live(conn, ~p"/admin/categories/#{category}")

    assert html =~ "Show Category"
    assert html =~ category.name
  end

  test "updates category and returns to show", %{conn: conn, category: category} do
    {:ok, show_live, _html} = live(conn, ~p"/admin/categories/#{category}")

    assert {:ok, form_live, _} =
             show_live
             |> element("a", "Edit")
             |> render_click()
             |> follow_redirect(conn, ~p"/admin/categories/#{category}/edit?return_to=show")

    assert render(form_live) =~ "Edit Category"

    assert form_live
           |> form("#category-form", category: %{name: nil})
           |> render_change() =~ "can&#39;t be blank"

    assert {:ok, show_live, _html} =
             form_live
             |> form("#category-form",
               category: %{name: "Renamed Category", tax_code_id: category.tax_code_id}
             )
             |> render_submit()
             |> follow_redirect(conn, ~p"/admin/categories/#{category}")

    html = render(show_live)
    assert html =~ "Category updated successfully"
    assert html =~ "Renamed Category"
  end
end
