defmodule Harbor.CatalogFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Harbor.Catalog` context.
  """
  alias Harbor.AccountsFixtures
  alias Harbor.Catalog
  alias Harbor.TaxFixtures

  def product_fixture(attrs \\ %{}) do
    category = category_fixture()

    {:ok, product} =
      attrs
      |> Enum.into(%{
        description: "some description",
        name: "some name",
        status: :active,
        category_id: category.id,
        variants: [
          %{
            sku: "sku-#{System.unique_integer()}",
            price: 4000,
            inventory_policy: :track_strict,
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
    scope = AccountsFixtures.admin_scope_fixture()
    tax_code = TaxFixtures.get_general_tax_code!()

    attrs =
      Enum.into(attrs, %{
        name: "some name-#{System.unique_integer()}",
        parent_ids: [],
        tax_code_id: tax_code.id
      })

    {:ok, category} = Catalog.create_category(scope, attrs)

    category
  end
end
