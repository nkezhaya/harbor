defmodule Harbor.CatalogFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Harbor.Catalog` context.
  """
  alias Harbor.Catalog
  alias Harbor.TaxFixtures

  def product_fixture(attrs \\ %{}) do
    tax_code = TaxFixtures.get_general_tax_code!()

    {:ok, product} =
      attrs
      |> Enum.into(%{
        description: "some description",
        name: "some name",
        slug: unique_product_slug(),
        status: :draft,
        tax_code_id: tax_code.id,
        variants: [
          %{
            master: true,
            sku: unique_product_slug(),
            price: 4000
          }
        ]
      })
      |> Catalog.create_product()

    product
  end

  def variant_fixture do
    product = product_fixture()

    Enum.find(product.variants, & &1.master)
  end

  def product_image_fixture(attrs \\ %{}) do
    {:ok, image} =
      attrs
      |> Enum.into(%{
        image: "some image",
        position: 0
      })
      |> Catalog.create_image()

    image
  end

  def unique_category_slug, do: "category-#{System.unique_integer([:positive])}"

  def category_fixture(attrs \\ %{}) do
    {:ok, category} =
      attrs
      |> Enum.into(%{
        name: "some name",
        slug: unique_category_slug(),
        position: 0,
        parent_ids: []
      })
      |> Catalog.create_category()

    category
  end

  defp unique_product_slug, do: "some-slug-#{System.unique_integer([:positive])}"
end
