defmodule Harbor.Web.ProductLive.ShowTest do
  use Harbor.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Harbor.CatalogFixtures

  alias Harbor.Catalog.Variant

  test "renders the product detail page", %{conn: conn} do
    product =
      product_fixture(%{
        name: "Wool Blanket",
        description: "Cozy throw blanket.",
        variants: [
          %{sku: "sku-#{System.unique_integer()}", price: Money.new(:USD, 54), enabled: true}
        ]
      })

    {:ok, view, _html} = live(conn, "/products/#{product.slug}")

    assert has_element?(view, "h1", "Wool Blanket")
    assert has_element?(view, "p", "Cozy throw blanket.")
  end

  test "selects variants through option groups", %{conn: conn} do
    product =
      product_with_options_fixture([
        {"Size", ["S", "M"]},
        {"Color", ["Black", "White"]}
      ])

    variant =
      Enum.find(product.variants, fn variant ->
        Enum.sort(Enum.map(variant.option_values, & &1.name)) == ["M", "White"]
      end)

    {:ok, view, _html} = live(conn, "/products/#{product.slug}")

    assert has_element?(view, "button[phx-value-option-value-id]", "M")
    assert has_element?(view, "button[phx-value-option-value-id]", "White")
    assert has_element?(view, "button[phx-click=add_to_cart][disabled]", "Select options")
    refute has_element?(view, "#details-heading")

    view
    |> element("button[phx-click=select-option]", "M")
    |> render_click()

    view
    |> element("button[phx-click=select-option]", "White")
    |> render_click()

    assert has_element?(view, "dd", variant.sku)
  end

  test "changing an earlier option clears incompatible later selections", %{conn: conn} do
    product =
      product_with_options_fixture([
        {"Size", ["S", "M"]},
        {"Color", ["Black", "White"]}
      ])

    Enum.each(product.variants, fn variant ->
      option_names = Enum.sort(Enum.map(variant.option_values, & &1.name))
      keep_variant? = option_names in [["Black", "S"], ["M", "White"]]

      variant
      |> Variant.changeset(%{enabled: keep_variant?})
      |> Repo.update!()
    end)

    sparse_product = Harbor.Catalog.get_storefront_product_by_slug!(product.slug)

    source_variant =
      Enum.find(sparse_product.variants, fn variant ->
        Enum.sort(Enum.map(variant.option_values, & &1.name)) == ["Black", "S"]
      end)

    target_variant =
      Enum.find(sparse_product.variants, fn variant ->
        Enum.sort(Enum.map(variant.option_values, & &1.name)) == ["M", "White"]
      end)

    {:ok, view, _html} = live(conn, "/products/#{product.slug}")

    view
    |> element("button[phx-click=select-option]", "S")
    |> render_click()

    view
    |> element("button[phx-click=select-option]", "Black")
    |> render_click()

    assert has_element?(view, "dd", source_variant.sku)
    refute has_element?(view, "button[disabled]", "M")

    view
    |> element("button[phx-click=select-option]", "M")
    |> render_click()

    assert has_element?(view, "button[disabled]", "Black")
    refute has_element?(view, "#details-heading")
    assert has_element?(view, "button[phx-click=add_to_cart][disabled]", "Select options")

    view
    |> element("button[phx-click=select-option]", "White")
    |> render_click()

    assert has_element?(view, "dd", target_variant.sku)
  end

  test "renders selectors for all images and allows selecting them", %{conn: conn} do
    product = product_fixture()

    images =
      Enum.map(0..4, fn position ->
        product_image_fixture(%{
          product_id: product.id,
          status: :ready,
          position: position,
          alt_text: "Image #{position}",
          image_path: "files/#{position}/original.jpg",
          temp_upload_path: "media_uploads/#{position}/original.jpg",
          file_name: "original-#{position}.jpg"
        })
      end)

    target_image = List.last(images)

    {:ok, view, _html} = live(conn, "/products/#{product.slug}")

    Enum.each(images, fn image ->
      assert has_element?(
               view,
               "button[phx-click=select-image][phx-value-image-id='#{image.id}']"
             )
    end)

    view
    |> element("button[phx-click=select-image][phx-value-image-id='#{target_image.id}']")
    |> render_click()

    assert has_element?(view, "img.aspect-square[alt='#{target_image.alt_text}']")
  end
end
