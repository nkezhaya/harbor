defmodule HarborWeb.Admin.ProductLive.IndexTest do
  use HarborWeb.ConnCase

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  alias Harbor.TaxFixtures

  setup :register_and_log_in_admin

  setup do
    product = product_fixture()
    [product: product]
  end

  test "lists all products", %{conn: conn, product: product} do
    {:ok, _index_live, html} = live(conn, ~p"/admin/products")

    assert html =~ "Listing Products"
    assert html =~ product.name
  end

  test "saves new product", %{conn: conn} do
    {:ok, index_live, _html} = live(conn, ~p"/admin/products")

    assert {:ok, form_live, _} =
             index_live
             |> element("a", "New Product")
             |> render_click()
             |> follow_redirect(conn, ~p"/admin/products/new")

    assert render(form_live) =~ "New Product"

    assert form_live
           |> form("#product-form", product: invalid_attrs())
           |> render_change() =~ "can&#39;t be blank"

    assert {:ok, index_live, _html} =
             form_live
             |> form("#product-form", product: create_attrs())
             |> render_submit()
             |> follow_redirect(conn, ~p"/admin/products")

    html = render(index_live)
    assert html =~ "Product created successfully"
    assert html =~ "some name"
  end

  test "updates product in listing", %{conn: conn, product: product} do
    {:ok, index_live, _html} = live(conn, ~p"/admin/products")

    assert {:ok, form_live, _html} =
             index_live
             |> element("#products-#{product.id} a", "Edit")
             |> render_click()
             |> follow_redirect(conn, ~p"/admin/products/#{product}/edit")

    assert render(form_live) =~ "Edit Product"

    assert form_live
           |> form("#product-form", product: invalid_attrs())
           |> render_change() =~ "can&#39;t be blank"

    assert {:ok, index_live, _html} =
             form_live
             |> form("#product-form", product: update_attrs())
             |> render_submit()
             |> follow_redirect(conn, ~p"/admin/products")

    html = render(index_live)
    assert html =~ "Product updated successfully"
    assert html =~ "some updated name"
  end

  test "deletes product in listing", %{conn: conn, product: product} do
    {:ok, index_live, _html} = live(conn, ~p"/admin/products")

    assert index_live |> element("#products-#{product.id} a", "Delete") |> render_click()
    refute has_element?(index_live, "#products-#{product.id}")
  end

  defp create_attrs do
    tax_code = TaxFixtures.get_general_tax_code!()

    %{
      name: "some name",
      status: :draft,
      description: "some description",
      tax_code_id: tax_code.id,
      variants: %{"0" => %{price: 4000}}
    }
  end

  defp update_attrs do
    %{
      name: "some updated name",
      status: :active,
      description: "some updated description"
    }
  end

  defp invalid_attrs do
    %{name: nil, status: nil, description: nil}
  end
end
