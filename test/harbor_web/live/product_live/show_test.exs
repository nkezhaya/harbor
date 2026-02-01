defmodule Harbor.Web.ProductLive.ShowTest do
  use Harbor.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

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
