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

  test "redirects simple products back to the product editor", %{conn: conn} do
    product = product_fixture(%{status: :draft})

    to = "/admin/products/#{product.id}"

    assert {:error, {:live_redirect, %{to: ^to, flash: flash}}} =
             live(conn, "/admin/products/#{product.id}/variants")

    assert flash["error"] ==
             "This product has no variants to edit here. Edit price and tax code on the product page."
  end

  test "renders option selects for purchasable variants", %{conn: conn} do
    product =
      product_with_options_fixture([{"Size", ["8"]}, {"Color", ["Black"]}], %{status: :draft})

    {:ok, view, _html} = live(conn, "/admin/products/#{product.id}/variants")

    assert has_element?(
             view,
             "select[name='product[variants][0][variant_option_values][0][product_option_value_id]']"
           )
  end

  test "keeps the master variant hidden while editing variants", %{conn: conn} do
    product = product_with_options_fixture([{"Size", ["S"]}])
    variant = List.first(product.variants)
    [variant_option_value] = variant.variant_option_values

    {:ok, view, _html} = live(conn, "/admin/products/#{product.id}/variants")

    params = %{
      "variants" => %{
        "0" => %{
          "id" => variant.id,
          "sku" => variant.sku,
          "price" => "45.00",
          "quantity_available" => Integer.to_string(variant.quantity_available),
          "enabled" => to_string(variant.enabled),
          "inventory_policy" => to_string(variant.inventory_policy),
          "variant_option_values" => %{
            "0" => %{
              "id" => variant_option_value.id,
              "product_option_id" => variant_option_value.product_option_id,
              "product_option_value_id" => variant_option_value.product_option_value_id
            }
          }
        }
      },
      "variants_sort" => ["0"]
    }

    assert {:ok, _show_live, _html} =
             view
             |> element("#product-variants-form")
             |> render_submit(%{"product" => params})
             |> follow_redirect(conn, "/admin/products/#{product.id}")

    product = Catalog.get_product!(product.id)

    assert product.master_variant.id == product.master_variant_id

    assert Enum.any?(product.variants, fn updated_variant ->
             updated_variant.price == Money.new(:USD, "45.00")
           end)
  end
end
