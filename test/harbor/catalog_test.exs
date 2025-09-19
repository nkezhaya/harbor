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
      assert product.slug == "some slug"
      assert product.tax_code_id == tax_code.id
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Catalog.create_product(%{name: nil, status: nil, description: nil, slug: nil})
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
      assert product.slug == "some updated slug"
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

  describe "list_product_images/0" do
    test "returns all product_images" do
      image = product_image_fixture()
      assert Catalog.list_product_images() == [image]
    end
  end

  describe "get_image!/1" do
    test "returns the image with given id" do
      image = product_image_fixture()
      assert Catalog.get_image!(image.id) == image
    end
  end

  describe "create_image/1" do
    setup do
      [product: product_fixture()]
    end

    test "with valid data creates a image" do
      valid_attrs = %{image: "some image", position: 0}

      assert {:ok, %ProductImage{} = image} = Catalog.create_image(valid_attrs)
      assert image.image == "some image"
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Catalog.create_image(%{image: nil})
    end
  end

  describe "update_image/2" do
    setup do
      [product: product_fixture()]
    end

    test "with valid data updates the image", %{product: product} do
      image = product_image_fixture(%{product_id: product.id})
      update_attrs = %{image: "some updated image", position: 1}

      assert {:ok, %ProductImage{} = image} = Catalog.update_image(image, update_attrs)
      assert image.image == "some updated image"
    end

    test "with invalid data returns error changeset", %{product: product} do
      image = product_image_fixture(%{product_id: product.id})
      assert {:error, %Ecto.Changeset{}} = Catalog.update_image(image, %{image: nil})
      assert image == Catalog.get_image!(image.id)
    end
  end

  describe "delete_image/1" do
    setup do
      [product: product_fixture()]
    end

    test "deletes the image", %{product: product} do
      image = product_image_fixture(%{product_id: product.id})
      assert {:ok, %ProductImage{}} = Catalog.delete_image(image)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_image!(image.id) end
    end
  end

  describe "change_image/1" do
    test "returns a image changeset" do
      image = product_image_fixture()
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
      assert category.slug == "some slug"
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
      assert category.slug == "some updated slug"
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
