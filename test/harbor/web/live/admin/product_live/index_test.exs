defmodule Harbor.Web.Admin.ProductLive.IndexTest do
  use Harbor.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  alias Harbor.{Catalog, Repo}
  alias Harbor.Catalog.Product

  setup :register_and_log_in_admin

  setup do
    taxon = taxon_fixture()
    product_type = product_type_fixture()
    product = product_fixture(%{primary_taxon_id: taxon.id, product_type_id: product_type.id})
    [taxon: taxon, product_type: product_type, product: product]
  end

  test "lists all products", %{conn: conn, product: product} do
    {:ok, index_live, _html} = live(conn, "/admin/products")

    assert has_element?(index_live, "h1", "Listing Products")
    assert has_element?(index_live, "#products-#{product.id}", product.name)
  end

  test "saves new product", %{conn: conn, taxon: taxon, product_type: product_type} do
    {:ok, index_live, _html} = live(conn, "/admin/products")

    assert {:ok, form_live, _} =
             index_live
             |> element("a", "New Product")
             |> render_click()
             |> follow_redirect(conn, "/admin/products/new")

    assert has_element?(form_live, "h1", "New Product")

    assert form_live
           |> form("#product-form", product: invalid_attrs())
           |> render_change() =~ "can&#39;t be blank"

    assert {:ok, index_live, _html} =
             form_live
             |> form("#product-form",
               product:
                 create_attrs(%{
                   primary_taxon_id: taxon.id,
                   product_type_id: product_type.id
                 })
             )
             |> render_submit()
             |> follow_redirect(conn, "/admin/products")

    assert has_element?(index_live, "[role=alert]", "Product created successfully")
    assert has_element?(index_live, "#products", "some name")
  end

  test "updates product in listing", %{conn: conn, product: product} do
    {:ok, index_live, _html} = live(conn, "/admin/products")

    assert {:ok, form_live, _html} =
             index_live
             |> element("#products-#{product.id} a", "Edit")
             |> render_click()
             |> follow_redirect(conn, "/admin/products/#{product.id}/edit")

    assert has_element?(form_live, "h1", "Edit Product")

    assert form_live
           |> form("#product-form", product: invalid_attrs())
           |> render_change() =~ "can&#39;t be blank"

    assert {:ok, index_live, _html} =
             form_live
             |> form("#product-form", product: update_attrs())
             |> render_submit()
             |> follow_redirect(conn, "/admin/products")

    assert has_element?(index_live, "[role=alert]", "Product updated successfully")
    assert has_element?(index_live, "#products", "some updated name")
  end

  test "deletes product in listing", %{conn: conn, product: product} do
    {:ok, index_live, _html} = live(conn, "/admin/products")

    assert index_live |> element("#products-#{product.id} a", "Delete") |> render_click()
    refute has_element?(index_live, "#products-#{product.id}")
  end

  test "saves a product with multiple taxons and product options", %{
    conn: conn,
    taxon: primary_taxon,
    product_type: product_type
  } do
    secondary_taxon = taxon_fixture()

    {:ok, index_live, _html} = live(conn, "/admin/products")

    assert {:ok, form_live, _} =
             index_live
             |> element("a", "New Product")
             |> render_click()
             |> follow_redirect(conn, "/admin/products/new")

    params = %{
      name: "Trail Shoe",
      status: :draft,
      description: "All-terrain running shoe.",
      primary_taxon_id: primary_taxon.id,
      taxon_ids: [primary_taxon.id, secondary_taxon.id],
      product_type_id: product_type.id,
      product_options_sort: ["0", "1"],
      product_options: %{
        "0" => %{
          "name" => "Size",
          "values_sort" => ["0", "1"],
          "values" => %{
            "0" => %{"name" => "8"},
            "1" => %{"name" => "9"}
          }
        },
        "1" => %{
          "name" => "Color",
          "values_sort" => ["0", "1"],
          "values" => %{
            "0" => %{"name" => "Black"},
            "1" => %{"name" => "White"}
          }
        }
      }
    }

    assert {:ok, _index_live, _html} =
             form_live
             |> element("#product-form")
             |> render_submit(%{"product" => params})
             |> follow_redirect(conn, "/admin/products")

    product = Repo.get_by!(Product, name: "Trail Shoe")
    product = Catalog.get_product!(product.id)

    assert Enum.map(product.product_taxons, & &1.taxon_id) == [
             primary_taxon.id,
             secondary_taxon.id
           ]

    assert Enum.map(product.product_options, & &1.name) == ["Size", "Color"]
    assert product.variants == []
  end

  defp create_attrs(attrs) do
    Enum.into(attrs, %{
      name: "some name",
      status: :draft,
      description: "some description"
    })
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
