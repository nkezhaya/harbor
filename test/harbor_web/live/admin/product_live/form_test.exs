defmodule HarborWeb.Admin.ProductLive.FormTest do
  use HarborWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  alias Harbor.Catalog.ProductImage
  alias Harbor.Repo

  setup :register_and_log_in_admin

  setup do
    product = product_fixture()
    [product: product]
  end

  test "sortable:reposition persists order on save", %{conn: conn, product: product} do
    i0 = product_image_fixture(%{product_id: product.id, position: 0})
    i1 = product_image_fixture(%{product_id: product.id, position: 1})
    i2 = product_image_fixture(%{product_id: product.id, position: 2})

    ids = [i0.id, i1.id, i2.id]
    reordered_ids = [i0.id, i2.id, i1.id]

    persisted_ids = image_ids_by_position(product)
    assert persisted_ids == ids

    {:ok, view, _html} = live(conn, ~p"/admin/products/#{product}/edit")
    view |> render_hook("sortable:reposition", %{"ids" => reordered_ids})

    attrs = %{
      name: product.name,
      description: product.description,
      status: product.status,
      tax_code_id: product.tax_code_id
    }

    assert {:ok, _index_live, _html} =
             view
             |> form("#product-form", product: attrs)
             |> render_submit()
             |> follow_redirect(conn, ~p"/admin/products")

    persisted_ids = image_ids_by_position(product)

    assert persisted_ids == reordered_ids
  end

  test "remove_media_upload removes a product image", %{conn: conn, product: product} do
    i0 = product_image_fixture(%{product_id: product.id, position: 0})
    i1 = product_image_fixture(%{product_id: product.id, position: 1})

    persisted_ids = image_ids_by_position(product)
    assert persisted_ids == [i0.id, i1.id]

    {:ok, view, _html} = live(conn, ~p"/admin/products/#{product}/edit")
    view |> render_hook("remove_media_upload", %{"id" => i0.id})

    attrs = %{
      name: product.name,
      description: product.description,
      status: product.status,
      tax_code_id: product.tax_code_id
    }

    assert {:ok, _index_live, _html} =
             view
             |> form("#product-form", product: attrs)
             |> render_submit()
             |> follow_redirect(conn, ~p"/admin/products")

    persisted_ids = image_ids_by_position(product)
    assert persisted_ids == [i1.id]
  end

  test "updates product and returns to show", %{conn: conn, product: product} do
    {:ok, show_live, _html} = live(conn, ~p"/admin/products/#{product}")

    assert {:ok, form_live, _} =
             show_live
             |> element("a", "Edit")
             |> render_click()
             |> follow_redirect(conn, ~p"/admin/products/#{product}/edit?return_to=show")

    assert render(form_live) =~ "Edit Product"

    assert form_live
           |> form("#product-form", product: %{name: nil})
           |> render_change() =~ "can&#39;t be blank"

    assert {:ok, show_live, _html} =
             form_live
             |> form("#product-form", product: %{name: "new name"})
             |> render_submit()
             |> follow_redirect(conn, ~p"/admin/products/#{product}")

    html = render(show_live)
    assert html =~ "Product updated successfully"
    assert html =~ "new name"
  end

  defp image_ids_by_position(product) do
    ProductImage
    |> where([image], image.product_id == ^product.id)
    |> order_by([image], image.position)
    |> select([image], image.id)
    |> Repo.all()
  end
end
