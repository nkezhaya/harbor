defmodule HarborWeb.Admin.ProductLiveTest do
  use HarborWeb.ConnCase

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  alias Harbor.Catalog.ProductImage
  alias Harbor.Repo
  alias Harbor.TaxFixtures

  setup :register_and_log_in_admin

  describe "Index" do
    setup :create_product

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
  end

  describe "Show" do
    setup :create_product

    test "displays product", %{conn: conn, product: product} do
      {:ok, _show_live, html} = live(conn, ~p"/admin/products/#{product}")

      assert html =~ product.name
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
             |> form("#product-form", product: invalid_attrs())
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#product-form", product: update_attrs())
               |> render_submit()
               |> follow_redirect(conn, ~p"/admin/products/#{product}")

      html = render(show_live)
      assert html =~ "Product updated successfully"
      assert html =~ "some updated name"
    end
  end

  describe "Form" do
    setup :create_product

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
  end

  defp create_product(_) do
    product = product_fixture()
    %{product: product}
  end

  defp image_ids_by_position(product) do
    ProductImage
    |> where([image], image.product_id == ^product.id)
    |> order_by([image], image.position)
    |> select([image], image.id)
    |> Repo.all()
  end

  defp create_attrs do
    tax_code = TaxFixtures.get_general_tax_code!()

    %{
      name: "some name",
      status: :draft,
      description: "some description",
      tax_code_id: tax_code.id
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
