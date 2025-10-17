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
        status: :active,
        tax_code_id: tax_code.id,
        variants: [
          %{
            sku: "sku-#{System.unique_integer()}",
            price: 4000,
            track_inventory: true,
            quantity_available: 10,
            enabled: true
          }
        ]
      })
      |> Catalog.create_product()

    product
  end

  def variant_fixture(attrs \\ %{}) do
    %{variants: [variant | _]} = product_fixture(attrs)

    variant
  end

  def product_image_fixture(attrs \\ %{}) do
    {:ok, image} =
      attrs
      |> Enum.into(%{
        image_path: "files/id/original.jpg",
        temp_upload_path: "media_uploads/id/original.jpg",
        position: 0,
        file_name: "original.jpg",
        file_type: "image/jpeg",
        file_size: 100_000
      })
      |> Catalog.create_image()

    image
  end

  def category_fixture(attrs \\ %{}) do
    {:ok, category} =
      attrs
      |> Enum.into(%{
        name: "some name",
        position: 0,
        parent_ids: []
      })
      |> Catalog.create_category()

    category
  end
end
