defmodule Harbor.CatalogTest do
  use Harbor.DataCase, async: true
  import Harbor.CatalogFixtures

  alias Harbor.AccountsFixtures
  alias Harbor.{Catalog, Repo}
  alias Harbor.Catalog.{Category, Product, ProductImage}
  alias Harbor.TaxFixtures

  describe "list_products/2" do
    setup do
      [scope: AccountsFixtures.admin_scope_fixture()]
    end

    test "returns all products with no params", %{scope: scope} do
      assert %{entries: [], total: 0} = Catalog.list_products(scope)
      product_fixture()
      assert %{entries: [_], total: 1} = Catalog.list_products(scope)
    end

    test "filters by status", %{scope: scope} do
      active = product_fixture(%{name: "Active Product"})
      _archived = product_fixture(%{name: "Archived Product", status: :archived})

      assert %{entries: [product]} = Catalog.list_products(scope, %{"status" => "active"})
      assert product.id == active.id
    end

    test "filters by category slug", %{scope: scope} do
      cat1 = category_fixture(%{name: "Apparel"})
      cat2 = category_fixture(%{name: "Electronics"})

      p1 = product_fixture(%{name: "Shirt", category_id: cat1.id})
      _p2 = product_fixture(%{name: "Phone", category_id: cat2.id})

      assert %{entries: [product]} = Catalog.list_products(scope, %{"category" => cat1.slug})
      assert product.id == p1.id
    end

    test "filters by price range", %{scope: scope} do
      product_fixture(%{
        name: "Cheap",
        variants: [
          %{
            sku: "cheap-1",
            price: 1000,
            inventory_policy: :not_tracked,
            quantity_available: 0,
            enabled: true
          }
        ]
      })

      product_fixture(%{
        name: "Mid",
        variants: [
          %{
            sku: "mid-1",
            price: 3000,
            inventory_policy: :not_tracked,
            quantity_available: 0,
            enabled: true
          }
        ]
      })

      product_fixture(%{
        name: "Expensive",
        variants: [
          %{
            sku: "exp-1",
            price: 8000,
            inventory_policy: :not_tracked,
            quantity_available: 0,
            enabled: true
          }
        ]
      })

      assert %{entries: [product]} =
               Catalog.list_products(scope, %{"price_min" => "2000", "price_max" => "5000"})

      assert product.name == "Mid"
    end

    test "sorts by price ascending", %{scope: scope} do
      product_fixture(%{
        name: "Expensive",
        variants: [
          %{
            sku: "exp-2",
            price: 8000,
            inventory_policy: :not_tracked,
            quantity_available: 0,
            enabled: true
          }
        ]
      })

      product_fixture(%{
        name: "Cheap",
        variants: [
          %{
            sku: "cheap-2",
            price: 1000,
            inventory_policy: :not_tracked,
            quantity_available: 0,
            enabled: true
          }
        ]
      })

      assert %{entries: [first, second]} =
               Catalog.list_products(scope, %{"sort" => "price_asc"})

      assert first.name == "Cheap"
      assert second.name == "Expensive"
    end

    test "sorts by name ascending", %{scope: scope} do
      product_fixture(%{name: "Zebra"})
      product_fixture(%{name: "Apple"})

      assert %{entries: [first, second]} =
               Catalog.list_products(scope, %{"sort" => "name_asc"})

      assert first.name == "Apple"
      assert second.name == "Zebra"
    end

    test "paginates results", %{scope: scope} do
      for i <- 1..7 do
        product_fixture(%{name: "Product #{i}"})
      end

      assert %{entries: products, total: 7, total_pages: 2, page: 1} =
               Catalog.list_products(scope, %{"per_page" => "5", "page" => "1"})

      assert length(products) == 5

      assert %{entries: products, page: 2} =
               Catalog.list_products(scope, %{"per_page" => "5", "page" => "2"})

      assert length(products) == 2
    end

    test "searches by name", %{scope: scope} do
      product_fixture(%{name: "Wool Blanket"})
      product_fixture(%{name: "Cotton Shirt"})

      assert %{entries: [product]} = Catalog.list_products(scope, %{"search" => "wool"})
      assert product.name == "Wool Blanket"
    end

    test "invalid params fall back to defaults", %{scope: scope} do
      product_fixture()

      assert %{entries: [_], page: 1} =
               Catalog.list_products(scope, %{"page" => "abc", "sort" => "invalid"})
    end

    test "filters by option values", %{scope: scope} do
      product = product_with_options_fixture([{"Color", ["Red", "Blue"]}])
      _other = product_fixture(%{name: "No Options"})

      assert %{entries: [matched]} =
               Catalog.list_products(scope, %{"options" => %{"color" => "red"}})

      assert matched.id == product.id
    end

    test "clamps page to total_pages", %{scope: scope} do
      product_fixture()

      assert %{page: 1, total_pages: 1} =
               Catalog.list_products(scope, %{"page" => "999"})
    end

    test "clamps per_page to 100", %{scope: scope} do
      product_fixture()

      assert %{per_page: 100} = Catalog.list_products(scope, %{"per_page" => "200"})
    end

    test "non-admin scope only sees active products" do
      guest_scope = Harbor.Accounts.Scope.for_guest()

      product_fixture(%{name: "Active Product"})
      product_fixture(%{name: "Draft Product", status: :draft})
      product_fixture(%{name: "Archived Product", status: :archived})

      assert %{entries: [product], total: 1} = Catalog.list_products(guest_scope, %{status: nil})
      assert product.name == "Active Product"
    end

    test "admin scope sees all products by default", %{scope: scope} do
      product_fixture(%{name: "Active Product"})
      product_fixture(%{name: "Draft Product", status: :draft})
      product_fixture(%{name: "Archived Product", status: :archived})

      assert %{entries: [_, _, _], total: 3} = Catalog.list_products(scope)
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
      category = category_fixture()

      valid_attrs = %{
        name: "some name",
        status: :draft,
        description: "some description",
        slug: "some slug",
        tax_code_id: tax_code.id,
        category_id: category.id
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
      category = category_fixture()

      attrs = %{
        name: "other product",
        status: :draft,
        description: "desc",
        category_id: category.id,
        tax_code_id: tax_code.id,
        default_variant_id: variant.id
      }

      assert {:error, changeset} = Catalog.create_product(attrs)
      assert "does not exist" in errors_on(changeset).default_variant_id

      attrs = %{attrs | default_variant_id: Ecto.UUID.generate()}
      assert {:error, changeset} = Catalog.create_product(attrs)
      assert "does not exist" in errors_on(changeset).default_variant_id
    end

    test "generates variants from option type permutations" do
      category = category_fixture()

      attrs = %{
        name: "T-Shirt",
        status: :active,
        category_id: category.id,
        option_types: [
          %{
            name: "Color",
            position: 0,
            values: [
              %{name: "Red", position: 0},
              %{name: "Blue", position: 1}
            ]
          },
          %{
            name: "Size",
            position: 1,
            values: [
              %{name: "S", position: 0},
              %{name: "M", position: 1}
            ]
          }
        ]
      }

      assert {:ok, product} = Catalog.create_product(attrs)
      assert length(product.variants) == 4
      assert product.default_variant_id

      product = Repo.preload(product, variants: :option_values)

      option_value_sets =
        product.variants
        |> Enum.map(fn variant ->
          variant.option_values |> Enum.map(& &1.name) |> Enum.sort()
        end)
        |> Enum.sort()

      assert option_value_sets == [
               ["Blue", "M"],
               ["Blue", "S"],
               ["M", "Red"],
               ["Red", "S"]
             ]

      for variant <- product.variants do
        assert length(variant.option_values) == 2
      end
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

  describe "list_categories/1" do
    test "returns all categories for admins" do
      admin_scope = AccountsFixtures.admin_scope_fixture()
      category = category_fixture(%{})

      assert Catalog.list_categories(admin_scope) == [category]
    end

    test "raises for non-admin scopes" do
      user_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Catalog.list_categories(user_scope)
      end
    end
  end

  describe "get_category!/2" do
    test "returns the category with given id" do
      admin_scope = AccountsFixtures.admin_scope_fixture()
      category = category_fixture(%{})
      assert Catalog.get_category!(admin_scope, category.id) == category
    end
  end

  describe "create_category/2" do
    test "with valid data creates a category" do
      admin_scope = AccountsFixtures.admin_scope_fixture()
      tax_code = TaxFixtures.get_general_tax_code!()

      valid_attrs = %{
        name: "some name",
        position: 42,
        slug: "some slug",
        tax_code_id: tax_code.id
      }

      assert {:ok, %Category{} = category} = Catalog.create_category(admin_scope, valid_attrs)
      assert category.name == "some name"
      assert category.position == 42
      assert category.slug == "some-slug"
    end

    test "with invalid data returns error changeset" do
      admin_scope = AccountsFixtures.admin_scope_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Catalog.create_category(admin_scope, %{name: nil, position: nil, slug: nil})
    end

    test "raises for non-admin scopes" do
      user_scope = AccountsFixtures.user_scope_fixture()
      tax_code = TaxFixtures.get_general_tax_code!()

      assert_raise Harbor.UnauthorizedError, fn ->
        Catalog.create_category(user_scope, %{name: "foo", tax_code_id: tax_code.id})
      end
    end
  end

  describe "update_category/3" do
    test "with valid data updates the category" do
      admin_scope = AccountsFixtures.admin_scope_fixture()
      category = category_fixture(%{})
      update_attrs = %{name: "some updated name", position: 43, slug: "some updated slug"}

      assert {:ok, %Category{} = category} =
               Catalog.update_category(admin_scope, category, update_attrs)

      assert category.name == "some updated name"
      assert category.position == 43
      assert category.slug == "some-updated-slug"
    end

    test "with invalid data returns error changeset" do
      admin_scope = AccountsFixtures.admin_scope_fixture()
      category = category_fixture(%{})

      assert {:error, %Ecto.Changeset{}} =
               Catalog.update_category(admin_scope, category, %{
                 name: nil,
                 position: nil,
                 slug: nil
               })

      assert category == Catalog.get_category!(admin_scope, category.id)
    end

    test "raises for non-admin scopes" do
      category = category_fixture(%{})
      user_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Catalog.update_category(user_scope, category, %{name: "updated"})
      end
    end
  end

  describe "delete_category/2" do
    test "deletes the category" do
      admin_scope = AccountsFixtures.admin_scope_fixture()
      category = category_fixture(%{})
      assert {:ok, %Category{}} = Catalog.delete_category(admin_scope, category)

      assert_raise Ecto.NoResultsError, fn ->
        Catalog.get_category!(admin_scope, category.id)
      end
    end

    test "raises for non-admin scopes" do
      category = category_fixture(%{})
      user_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Catalog.delete_category(user_scope, category)
      end
    end
  end

  describe "change_category/3" do
    test "returns a category changeset" do
      admin_scope = AccountsFixtures.admin_scope_fixture()
      category = category_fixture(%{})
      assert %Ecto.Changeset{} = Catalog.change_category(admin_scope, category)
    end

    test "raises for non-admin scopes" do
      category = category_fixture(%{})
      user_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Catalog.change_category(user_scope, category)
      end
    end
  end
end
