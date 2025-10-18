defmodule HarborWeb.ProductsLive.IndexTest do
  use HarborWeb.ConnCase

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  test "lists active products with links", %{conn: conn} do
    product = product_fixture(%{name: "Ceramic Mug"})
    _archived = product_fixture(%{name: "Archived Item", status: :archived})

    {:ok, view, _html} = live(conn, ~p"/products")

    assert has_element?(view, "a[href=\"/products/#{product.slug}\"]", "Ceramic Mug")
    refute render(view) =~ "Archived Item"
  end
end
