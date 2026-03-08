defmodule Harbor.CatalogTest do
  use Harbor.DataCase, async: true
  import Harbor.CatalogFixtures

  alias Harbor.AccountsFixtures
  alias Harbor.Catalog
  alias Harbor.Catalog.{Product, ProductImage, Taxon}
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

    test "filters by taxon slug", %{scope: scope} do
      taxon_1 = taxon_fixture(%{name: "Apparel"})
      taxon_2 = taxon_fixture(%{name: "Electronics"})

      p1 = product_fixture(%{name: "Shirt", primary_taxon_id: taxon_1.id})
      _p2 = product_fixture(%{name: "Phone", primary_taxon_id: taxon_2.id})

      assert %{entries: [product]} = Catalog.list_products(scope, %{"taxon" => taxon_1.slug})
      assert product.id == p1.id
    end

    test "filters by price range", %{scope: scope} do
      product_fixture(%{
        name: "Cheap",
        variants: [
          %{
            sku: "cheap-1",
            price: Money.new(:USD, 10),
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
            price: Money.new(:USD, 30),
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
            price: Money.new(:USD, 80),
            inventory_policy: :not_tracked,
            quantity_available: 0,
            enabled: true
          }
        ]
      })

      assert %{entries: [product]} =
               Catalog.list_products(scope, %{"price_min" => "20", "price_max" => "50"})

      assert product.name == "Mid"
    end

    test "sorts by price ascending", %{scope: scope} do
      product_fixture(%{
        name: "Expensive",
        variants: [
          %{
            sku: "exp-2",
            price: Money.new(:USD, 80),
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
            price: Money.new(:USD, 10),
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
      taxon = taxon_fixture()
      product_type = product_type_fixture()

      valid_attrs = %{
        name: "some name",
        status: :draft,
        description: "some description",
        slug: "some slug",
        tax_code_id: tax_code.id,
        primary_taxon_id: taxon.id,
        product_type_id: product_type.id
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
      taxon = taxon_fixture()
      product_type = product_type_fixture()

      attrs = %{
        name: "other product",
        status: :draft,
        description: "desc",
        primary_taxon_id: taxon.id,
        tax_code_id: tax_code.id,
        product_type_id: product_type.id,
        default_variant_id: variant.id
      }

      assert {:error, changeset} = Catalog.create_product(attrs)
      assert "does not exist" in errors_on(changeset).default_variant_id

      attrs = %{attrs | default_variant_id: Ecto.UUID.generate()}
      assert {:error, changeset} = Catalog.create_product(attrs)
      assert "does not exist" in errors_on(changeset).default_variant_id
    end

    test "creates explicit variant rows without generating missing combinations" do
      taxon = taxon_fixture()
      product_type = product_type_fixture()

      attrs = %{
        name: "T-Shirt",
        status: :active,
        primary_taxon_id: taxon.id,
        product_type_id: product_type.id,
        variants: [
          %{
            sku: "tee-black-s",
            price: Money.new(:USD, 20),
            inventory_policy: :track_strict,
            quantity_available: 5,
            enabled: true
          },
          %{
            sku: "tee-black-m",
            price: Money.new(:USD, 20),
            inventory_policy: :track_strict,
            quantity_available: 4,
            enabled: true
          }
        ]
      }

      assert {:ok, product} = Catalog.create_product(attrs)
      assert length(product.variants) == 2
      assert product.default_variant_id
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

  describe "list_taxons/0" do
    test "returns all taxons" do
      taxon = taxon_fixture(%{})

      assert Catalog.list_taxons() == [taxon]
    end
  end

  describe "get_taxon!/2" do
    test "returns the taxon with given id" do
      admin_scope = AccountsFixtures.admin_scope_fixture()
      taxon = taxon_fixture(%{})
      assert Catalog.get_taxon!(admin_scope, taxon.id) == taxon
    end
  end

  describe "create_taxon/2" do
    test "with valid data creates a taxon" do
      admin_scope = AccountsFixtures.admin_scope_fixture()

      valid_attrs = %{
        name: "some name",
        position: 42,
        slug: "some slug"
      }

      assert {:ok, %Taxon{} = taxon} = Catalog.create_taxon(admin_scope, valid_attrs)
      assert taxon.name == "some name"
      assert taxon.position == 42
      assert taxon.slug == "some-slug"
    end

    test "with invalid data returns error changeset" do
      admin_scope = AccountsFixtures.admin_scope_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Catalog.create_taxon(admin_scope, %{name: nil, position: nil, slug: nil})
    end

    test "raises for non-admin scopes" do
      user_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Catalog.create_taxon(user_scope, %{name: "foo"})
      end
    end
  end

  describe "update_taxon/3" do
    test "with valid data updates the taxon" do
      admin_scope = AccountsFixtures.admin_scope_fixture()
      taxon = taxon_fixture(%{})
      update_attrs = %{name: "some updated name", position: 43, slug: "some updated slug"}

      assert {:ok, %Taxon{} = taxon} =
               Catalog.update_taxon(admin_scope, taxon, update_attrs)

      assert taxon.name == "some updated name"
      assert taxon.position == 43
      assert taxon.slug == "some-updated-slug"
    end

    test "with invalid data returns error changeset" do
      admin_scope = AccountsFixtures.admin_scope_fixture()
      taxon = taxon_fixture(%{})

      assert {:error, %Ecto.Changeset{}} =
               Catalog.update_taxon(admin_scope, taxon, %{
                 name: nil,
                 position: nil,
                 slug: nil
               })

      assert taxon == Catalog.get_taxon!(admin_scope, taxon.id)
    end

    test "raises for non-admin scopes" do
      taxon = taxon_fixture(%{})
      user_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Catalog.update_taxon(user_scope, taxon, %{name: "updated"})
      end
    end
  end

  describe "delete_taxon/2" do
    test "deletes the taxon" do
      admin_scope = AccountsFixtures.admin_scope_fixture()
      taxon = taxon_fixture(%{})
      assert {:ok, %Taxon{}} = Catalog.delete_taxon(admin_scope, taxon)

      assert_raise Ecto.NoResultsError, fn ->
        Catalog.get_taxon!(admin_scope, taxon.id)
      end
    end

    test "raises for non-admin scopes" do
      taxon = taxon_fixture(%{})
      user_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Catalog.delete_taxon(user_scope, taxon)
      end
    end
  end

  describe "change_taxon/3" do
    test "returns a taxon changeset" do
      admin_scope = AccountsFixtures.admin_scope_fixture()
      taxon = taxon_fixture(%{})
      assert %Ecto.Changeset{} = Catalog.change_taxon(admin_scope, taxon)
    end

    test "raises for non-admin scopes" do
      taxon = taxon_fixture(%{})
      user_scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Catalog.change_taxon(user_scope, taxon)
      end
    end
  end
end
