defmodule Harbor.Web.Admin.ProductLiveTest do
  use Harbor.Web.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  setup :register_and_log_in_admin

  setup do
    product = product_fixture()
    [product: product]
  end

  test "displays product", %{conn: conn, product: product} do
    {:ok, _show_live, html} = live(conn, "/admin/products/#{product.id}")

    assert html =~ product.name
  end
end
