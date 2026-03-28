defmodule Harbor.Web.Admin.ProductLive.VariantFormTest do
  use Harbor.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  alias Harbor.Catalog

  setup :register_and_log_in_admin

  test "saves variants for a persisted product", %{conn: conn} do
    product =
      product_fixture(%{
        status: :draft,
        variants: [],
        product_options: [
          %{name: "Size", values: [%{name: "8"}, %{name: "9"}]},
          %{name: "Color", values: [%{name: "Black"}, %{name: "White"}]}
        ]
      })

    [size_option, color_option] = product.product_options
    [size_8 | _] = size_option.values
    [color_black | _] = color_option.values

    {:ok, view, _html} = live(conn, "/admin/products/#{product.id}/variants")

    params = %{
      "variants_sort" => ["0"],
      "variants" => %{
        "0" => %{
          "sku" => "trail-shoe-8-black",
          "price" => "80.00",
          "quantity_available" => "10",
          "enabled" => "true",
          "inventory_policy" => "track_strict",
          "variant_option_values" => %{
            "0" => %{
              "product_option_id" => size_option.id,
              "product_option_value_id" => size_8.id
            },
            "1" => %{
              "product_option_id" => color_option.id,
              "product_option_value_id" => color_black.id
            }
          }
        }
      }
    }

    assert {:ok, show_live, _html} =
             view
             |> element("#product-variants-form")
             |> render_submit(%{"product" => params})
             |> follow_redirect(conn, "/admin/products/#{product.id}")

    assert has_element?(show_live, "[role=alert]", "Variants updated successfully")

    product = Catalog.get_product!(product.id)

    assert Enum.map(product.variants, fn variant ->
             variant.option_values
             |> Enum.map(& &1.name)
             |> Enum.sort()
           end) == [["8", "Black"]]
  end

  test "renders one option select per persisted product option", %{conn: conn} do
    product =
      product_fixture(%{
        status: :draft,
        variants: [],
        product_options: [
          %{name: "Size", values: [%{name: "8"}]},
          %{name: "Color", values: [%{name: "Black"}]}
        ]
      })

    {:ok, view, _html} = live(conn, "/admin/products/#{product.id}/variants")

    assert has_element?(
             view,
             "#product_variants_0_variant_option_values_0_product_option_value_id"
           )

    assert has_element?(
             view,
             "#product_variants_0_variant_option_values_1_product_option_value_id"
           )
  end

  test "shows validation when removing the last variant from an active product", %{conn: conn} do
    product = product_with_options_fixture([{"Size", ["S"]}])
    variant = List.first(product.variants)

    {:ok, view, _html} = live(conn, "/admin/products/#{product.id}/variants")

    params = %{
      "variants" => %{
        "0" => %{"id" => variant.id}
      },
      "variants_sort" => ["0"],
      "variants_drop" => ["0"]
    }

    view
    |> element("#product-variants-form")
    |> render_submit(%{"product" => params})

    assert has_element?(view, "p", "active products must have at least one variant")
  end
end
