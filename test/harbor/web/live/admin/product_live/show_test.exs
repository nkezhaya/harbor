defmodule Harbor.Web.Admin.ProductLiveTest do
  use Harbor.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  setup :register_and_log_in_admin

  setup do
    product = product_fixture()
    [product: product]
  end

  test "displays product", %{conn: conn, product: product} do
    {:ok, show_live, _html} = live(conn, "/admin/products/#{product.id}")

    assert has_element?(show_live, "h1", "Product #{product.name}")
    assert has_element?(show_live, "a", "Edit product")
    assert has_element?(show_live, "a", "Edit variants")
  end
end
