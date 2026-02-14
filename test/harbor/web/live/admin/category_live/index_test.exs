defmodule Harbor.Web.Admin.CategoryLive.IndexTest do
  use Harbor.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  alias Harbor.TaxFixtures

  setup :register_and_log_in_admin

  setup do
    category = category_fixture(%{})

    %{category: category}
  end

  test "lists all categories", %{conn: conn, category: category} do
    {:ok, _index_live, html} = live(conn, "/admin/categories")

    assert html =~ "Listing Categories"
    assert html =~ category.name
  end

  test "saves new category", %{conn: conn} do
    {:ok, index_live, _html} = live(conn, "/admin/categories")

    assert {:ok, form_live, _} =
             index_live
             |> element("a", "New Category")
             |> render_click()
             |> follow_redirect(conn, "/admin/categories/new")

    assert render(form_live) =~ "New Category"

    assert form_live
           |> form("#category-form", category: invalid_attrs())
           |> render_change() =~ "can&#39;t be blank"

    assert {:ok, index_live, _html} =
             form_live
             |> form("#category-form", category: create_attrs())
             |> render_submit()
             |> follow_redirect(conn, "/admin/categories")

    html = render(index_live)
    assert html =~ "Category created successfully"
    assert html =~ "New Category"
  end

  test "updates category in listing", %{conn: conn, category: category} do
    {:ok, index_live, _html} = live(conn, "/admin/categories")

    assert {:ok, form_live, _html} =
             index_live
             |> element("#categories-#{category.id} a", "Edit")
             |> render_click()
             |> follow_redirect(conn, "/admin/categories/#{category.id}/edit")

    assert render(form_live) =~ "Edit Category"

    assert form_live
           |> form("#category-form", category: invalid_attrs())
           |> render_change() =~ "can&#39;t be blank"

    assert {:ok, index_live, _html} =
             form_live
             |> form("#category-form", category: update_attrs())
             |> render_submit()
             |> follow_redirect(conn, "/admin/categories")

    html = render(index_live)
    assert html =~ "Category updated successfully"
    assert html =~ "Updated Category"
  end

  test "deletes category in listing", %{conn: conn, category: category} do
    {:ok, index_live, _html} = live(conn, "/admin/categories")

    assert index_live |> element("#categories-#{category.id} a", "Delete") |> render_click()
    refute has_element?(index_live, "#categories-#{category.id}")
  end

  defp create_attrs do
    tax_code = TaxFixtures.get_general_tax_code!()

    %{
      name: "New Category",
      slug: "new-category",
      position: "1",
      tax_code_id: tax_code.id
    }
  end

  defp update_attrs do
    tax_code = TaxFixtures.get_general_tax_code!()

    %{
      name: "Updated Category",
      slug: "updated-category",
      position: "2",
      tax_code_id: tax_code.id
    }
  end

  defp invalid_attrs do
    %{
      name: nil,
      slug: nil,
      position: nil,
      tax_code_id: nil
    }
  end
end
