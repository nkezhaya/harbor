defmodule Harbor.Web.Admin.ProductLive.FormTest do
  use Harbor.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  alias Harbor.Catalog.ProductImage
  alias Harbor.Repo

  setup :register_and_log_in_admin

  setup do
    product = product_fixture(%{status: :draft, variants: []})
    [product: product]
  end

  test "adds a product option row", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, "/admin/products/#{product.id}/edit")

    refute has_element?(view, "#product_product_options_0_name")

    params =
      change_params(product)
      |> Map.put("product_options", %{})
      |> Map.put("product_options_sort", ["new"])

    view
    |> element("#product-form")
    |> render_change(%{"product" => params})

    assert has_element?(view, "#product_product_options_0_name")
  end

  test "loads existing product option value rows on edit", %{conn: conn} do
    product =
      product_fixture(%{
        status: :draft,
        variants: [],
        product_options: [
          %{name: "Size", values: [%{name: "Small"}, %{name: "Medium"}]},
          %{name: "Color", values: [%{name: "Black"}]}
        ]
      })

    {:ok, view, _html} = live(conn, "/admin/products/#{product.id}/edit")

    assert has_element?(view, "#product_product_options_0_name")
    assert has_element?(view, "#product_product_options_0_values_0_name")
    assert has_element?(view, "#product_product_options_1_values_0_name")
  end

  test "adds a product option value row", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, "/admin/products/#{product.id}/edit")

    params = %{
      "name" => product.name,
      "description" => product.description,
      "status" => to_string(product.status),
      "primary_taxon_id" => product.primary_taxon_id,
      "taxon_ids" => [product.primary_taxon_id],
      "product_type_id" => product.product_type_id,
      "product_options" => %{
        "0" => %{
          "name" => "Size",
          "values" => %{
            "0" => %{"name" => "Small"}
          },
          "values_sort" => ["0", "new"]
        }
      },
      "product_options_sort" => ["0"]
    }

    view
    |> element("#product-form")
    |> render_change(%{"product" => params})

    assert has_element?(view, "#product_product_options_0_values_1_name")
  end

  test "shows product pricing fields inline on the product editor", %{
    conn: conn,
    product: product
  } do
    {:ok, view, _html} = live(conn, "/admin/products/#{product.id}/edit")

    assert has_element?(view, "[name='product[master_variant][price]']")
    refute has_element?(view, "[name='product[master_variant][tax_code_id]']")
    refute has_element?(view, "#product-form", "Master Variant")
    refute has_element?(view, "[name='product[master_variant][sku]']")
    refute has_element?(view, "[name='product[master_variant][quantity_available]']")
    refute has_element?(view, "[name='product[master_variant][inventory_policy]']")
    refute has_element?(view, "[name='product[master_variant][enabled]']")
    assert has_element?(view, "a", "Edit Variants")
    refute has_element?(view, "#product_variants_0_sku")
  end

  test "locks option editing once variants exist", %{conn: conn} do
    product = product_with_options_fixture([{"Size", ["S", "M"]}])

    {:ok, view, _html} = live(conn, "/admin/products/#{product.id}/edit")

    assert has_element?(view, "div", "Product options are locked once variants exist")
    refute has_element?(view, "#product_product_options_0_name")
    refute has_element?(view, "button", "Add Product Option")
  end

  test "sortable:reposition persists order on save", %{conn: conn, product: product} do
    i0 = product_image_fixture(%{product_id: product.id, position: 0})
    i1 = product_image_fixture(%{product_id: product.id, position: 1})
    i2 = product_image_fixture(%{product_id: product.id, position: 2})

    ids = [i0.id, i1.id, i2.id]
    reordered_ids = [i0.id, i2.id, i1.id]

    persisted_ids = image_ids_by_position(product)
    assert persisted_ids == ids

    {:ok, view, _html} = live(conn, "/admin/products/#{product.id}/edit")
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
             |> follow_redirect(conn, "/admin/products")

    persisted_ids = image_ids_by_position(product)

    assert persisted_ids == reordered_ids
  end

  test "remove_media_upload removes a product image", %{conn: conn, product: product} do
    i0 = product_image_fixture(%{product_id: product.id, position: 0})
    i1 = product_image_fixture(%{product_id: product.id, position: 1})

    persisted_ids = image_ids_by_position(product)
    assert persisted_ids == [i0.id, i1.id]

    {:ok, view, _html} = live(conn, "/admin/products/#{product.id}/edit")
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
             |> follow_redirect(conn, "/admin/products")

    persisted_ids = image_ids_by_position(product)
    assert persisted_ids == [i1.id]
  end

  test "updates product and returns to show", %{conn: conn, product: product} do
    {:ok, show_live, _html} = live(conn, "/admin/products/#{product.id}")

    assert {:ok, form_live, _} =
             show_live
             |> element("a", "Edit product")
             |> render_click()
             |> follow_redirect(conn, "/admin/products/#{product.id}/edit?return_to=show")

    assert has_element?(form_live, "h1", "Edit Product")

    form_live
    |> form("#product-form", product: %{name: nil})
    |> render_change()

    assert has_element?(form_live, "p", "can't be blank")

    assert {:ok, show_live, _html} =
             form_live
             |> form("#product-form", product: %{name: "new name"})
             |> render_submit()
             |> follow_redirect(conn, "/admin/products/#{product.id}")

    assert has_element?(show_live, "[role=alert]", "Product updated successfully")
    assert has_element?(show_live, "h1", "Product new name")
  end

  test "shows duplicate option name errors on submit", %{conn: conn, product: product} do
    {:ok, view, _html} = live(conn, "/admin/products/#{product.id}/edit")

    params = %{
      "name" => product.name,
      "description" => product.description,
      "status" => to_string(product.status),
      "product_type_id" => product.product_type_id,
      "primary_taxon_id" => product.primary_taxon_id,
      "taxon_ids" => [product.primary_taxon_id],
      "product_options" => %{
        "0" => %{
          "name" => "Size",
          "values_sort" => ["0"],
          "values" => %{"0" => %{"name" => "S"}}
        },
        "1" => %{
          "name" => "Size",
          "values_sort" => ["0"],
          "values" => %{"0" => %{"name" => "M"}}
        }
      },
      "product_options_sort" => ["0", "1"]
    }

    view
    |> element("#product-form")
    |> render_change(%{"product" => params})

    refute has_element?(view, "p", "has already been taken")

    view
    |> element("#product-form")
    |> render_submit(%{"product" => params})

    assert has_element?(view, "p", "has already been taken")
  end

  test "updates the master variant on the product editor", %{conn: conn} do
    product = product_fixture(%{status: :draft, variants: []})

    {:ok, view, _html} = live(conn, "/admin/products/#{product.id}/edit")

    params = %{
      "name" => product.name,
      "description" => product.description,
      "status" => to_string(product.status),
      "primary_taxon_id" => product.primary_taxon_id,
      "taxon_ids" => [product.primary_taxon_id],
      "product_type_id" => product.product_type_id,
      "master_variant" => %{
        "id" => product.master_variant_id,
        "price" => "25.00"
      }
    }

    assert {:ok, _index_live, _html} =
             view
             |> element("#product-form")
             |> render_submit(%{"product" => params})
             |> follow_redirect(conn, "/admin/products")

    product = Harbor.Catalog.get_product!(product.id)

    assert product.master_variant.price == Money.new(:USD, "25.00")
  end

  defp image_ids_by_position(product) do
    ProductImage
    |> where([image], image.product_id == ^product.id)
    |> order_by([image], image.position)
    |> select([image], image.id)
    |> Repo.all()
  end

  defp change_params(product) do
    %{
      "name" => product.name,
      "description" => product.description,
      "status" => to_string(product.status),
      "primary_taxon_id" => product.primary_taxon_id,
      "taxon_ids" => [product.primary_taxon_id],
      "product_type_id" => product.product_type_id
    }
  end
end
