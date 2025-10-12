defmodule HarborWeb.ProductsLiveTest do
  use HarborWeb.ConnCase

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  describe "Index" do
    test "lists active products with links", %{conn: conn} do
      product = product_fixture(%{name: "Ceramic Mug"})
      _archived = product_fixture(%{name: "Archived Item", status: :archived})

      {:ok, view, _html} = live(conn, ~p"/products")

      assert has_element?(view, "a[href=\"/products/#{product.slug}\"]", "Ceramic Mug")
      refute render(view) =~ "Archived Item"
    end
  end

  describe "Show" do
    test "renders the product detail page", %{conn: conn} do
      product =
        product_fixture(%{
          name: "Wool Blanket",
          description: "Cozy throw blanket.",
          variants: [%{sku: "sku-#{System.unique_integer()}", price: 5400, enabled: true}]
        })

      {:ok, _view, html} = live(conn, ~p"/products/#{product.slug}")

      assert html =~ "Wool Blanket"
      assert html =~ "Cozy throw blanket."
    end
  end
end
