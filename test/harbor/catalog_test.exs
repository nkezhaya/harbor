defmodule Harbor.CatalogTest do
  use Harbor.DataCase
  import Harbor.CatalogFixtures

  alias Harbor.Catalog
  alias Harbor.Catalog.{Category, Product, ProductImage}
  alias Harbor.TaxFixtures

  describe "list_products/0" do
    test "returns all products" do
      product = product_fixture()
      assert Catalog.list_products() == [product]
    end
  end

  describe "list_storefront_products/0" do
    test "returns active products with associations" do
      product = product_fixture()

      # Create an archived product that shouldn't be returned
      product_fixture(%{status: :archived})

      assert [storefront_product] = Catalog.list_storefront_products()
      assert storefront_product.id == product.id
    end
  end

  describe "get_storefront_product_by_slug!/1" do
    test "fetches an active product by slug" do
      product = product_fixture(%{name: "Wool Blanket"})
      assert Catalog.get_storefront_product_by_slug!(product.slug).id == product.id

      archived = product_fixture(%{name: "Archived", status: :archived})

      assert_raise Ecto.NoResultsError, fn ->
        Catalog.get_storefront_product_by_slug!(archived.slug)
      end
    end
  end

  describe "get_product!/1" do
    test "returns the product with given id" do
      product = product_fixture()
      assert Catalog.get_product!(product.id) == product
    end
  end

  describe "create_product/1" do
    test "with valid data creates a product" do
      tax_code = TaxFixtures.get_general_tax_code!()

      valid_attrs = %{
        name: "some name",
        status: :draft,
        description: "some description",
        slug: "some slug",
        tax_code_id: tax_code.id
      }

      assert {:ok, %Product{} = product} = Catalog.create_product(valid_attrs)
      assert product.name == "some name"
      assert product.status == :draft
      assert product.description == "some description"
      assert product.slug == "some-slug"
      assert product.tax_code_id == tax_code.id
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Catalog.create_product(%{name: nil, status: nil, description: nil, slug: nil})
    end

    test "fails when default_variant_id does not belong to the product" do
      other_product = product_fixture()
      variant = List.first(other_product.variants)
      tax_code = TaxFixtures.get_general_tax_code!()

      attrs = %{
        name: "other product",
        status: :draft,
        description: "desc",
        tax_code_id: tax_code.id,
        default_variant_id: variant.id
      }

      assert {:error, changeset} = Catalog.create_product(attrs)
      assert "does not exist" in errors_on(changeset).default_variant

      attrs = %{attrs | default_variant_id: Ecto.UUID.generate()}
      assert {:error, changeset} = Catalog.create_product(attrs)
      assert "does not exist" in errors_on(changeset).default_variant
    end
  end

  describe "update_product/2" do
    test "with valid data updates the product" do
      product = product_fixture()

      update_attrs = %{
        name: "some updated name",
        status: :active,
        description: "some updated description",
        slug: "some updated slug"
      }

      assert {:ok, %Product{} = product} = Catalog.update_product(product, update_attrs)
      assert product.name == "some updated name"
      assert product.status == :active
      assert product.description == "some updated description"
      assert product.slug == "some-updated-slug"
    end

    test "with invalid data returns error changeset" do
      product = product_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Catalog.update_product(product, %{
                 name: nil,
                 status: nil,
                 description: nil,
                 slug: nil
               })

      assert product == Catalog.get_product!(product.id)
    end

    test "allows setting default_variant_id for a product variant" do
      product = product_fixture()
      variant = List.first(product.variants)

      assert {:ok, %Product{} = updated} =
               Catalog.update_product(product, %{default_variant_id: variant.id})

      assert updated.default_variant_id == variant.id
    end
  end

  describe "delete_product/1" do
    test "deletes the product" do
      product = product_fixture()
      assert {:ok, %Product{}} = Catalog.delete_product(product)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_product!(product.id) end
    end
  end

  describe "change_product/1" do
    test "returns a product changeset" do
      product = product_fixture()
      assert %Ecto.Changeset{} = Catalog.change_product(product)
    end
  end

  describe "get_image!/1" do
    test "returns the image with given id" do
      product = product_fixture()
      image = product_image_fixture(%{product_id: product.id})
      assert Catalog.get_image!(image.id) == image
    end
  end

  describe "create_image/1" do
    setup do
      [product: product_fixture()]
    end

    test "with valid data creates a image", %{product: product} do
      valid_attrs = %{
        product_id: product.id,
        image_path: "files/id/original.jpg",
        temp_upload_path: "media_uploads/id/original.jpg",
        position: 0,
        file_name: "original.jpg",
        file_type: "image/jpeg",
        file_size: 100_000
      }

      assert {:ok, %ProductImage{} = image} = Catalog.create_image(valid_attrs)
      assert image.image_path == "files/id/original.jpg"
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_image(%{})
    end
  end

  describe "update_image/2" do
    setup do
      [product: product_fixture()]
    end

    test "with valid data updates the image", %{product: product} do
      image = product_image_fixture(%{product_id: product.id})
      update_attrs = %{image_path: "updated/path", position: 1}

      assert {:ok, %ProductImage{} = image} = Catalog.update_image(image, update_attrs)
      assert image.image_path == "updated/path"
    end

    test "with invalid data returns error changeset", %{product: product} do
      image = product_image_fixture(%{product_id: product.id})
      assert {:error, %Ecto.Changeset{}} = Catalog.update_image(image, %{image_path: nil})
      assert image == Catalog.get_image!(image.id)
    end
  end

  describe "delete_image/1" do
    test "deletes the image" do
      product = product_fixture()
      image = product_image_fixture(%{product_id: product.id})
      assert {:ok, %ProductImage{}} = Catalog.delete_image(image)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_image!(image.id) end
    end
  end

  describe "change_image/1" do
    test "returns a image changeset" do
      product = product_fixture()
      image = product_image_fixture(%{product_id: product.id})
      assert %Ecto.Changeset{} = Catalog.change_image(image)
    end
  end

  describe "list_categories/0" do
    test "returns all categories" do
      category = category_fixture()
      assert Catalog.list_categories() == [category]
    end
  end

  describe "get_category!/1" do
    test "returns the category with given id" do
      category = category_fixture()
      assert Catalog.get_category!(category.id) == category
    end
  end

  describe "create_category/1" do
    test "with valid data creates a category" do
      valid_attrs = %{name: "some name", position: 42, slug: "some slug"}

      assert {:ok, %Category{} = category} = Catalog.create_category(valid_attrs)
      assert category.name == "some name"
      assert category.position == 42
      assert category.slug == "some-slug"
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Catalog.create_category(%{name: nil, position: nil, slug: nil})
    end
  end

  describe "update_category/2" do
    test "with valid data updates the category" do
      category = category_fixture()
      update_attrs = %{name: "some updated name", position: 43, slug: "some updated slug"}

      assert {:ok, %Category{} = category} = Catalog.update_category(category, update_attrs)
      assert category.name == "some updated name"
      assert category.position == 43
      assert category.slug == "some-updated-slug"
    end

    test "with invalid data returns error changeset" do
      category = category_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Catalog.update_category(category, %{name: nil, position: nil, slug: nil})

      assert category == Catalog.get_category!(category.id)
    end
  end

  describe "delete_category/1" do
    test "deletes the category" do
      category = category_fixture()
      assert {:ok, %Category{}} = Catalog.delete_category(category)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_category!(category.id) end
    end
  end

  describe "change_category/1" do
    test "returns a category changeset" do
      category = category_fixture()
      assert %Ecto.Changeset{} = Catalog.change_category(category)
    end
  end
end
