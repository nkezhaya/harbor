defmodule HarborWeb.Admin.ProductLiveTest do
  use HarborWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  setup :register_and_log_in_admin

  setup do
    product = product_fixture()
    [product: product]
  end

  test "displays product", %{conn: conn, product: product} do
    {:ok, _show_live, html} = live(conn, ~p"/admin/products/#{product}")

    assert html =~ product.name
  end
end
