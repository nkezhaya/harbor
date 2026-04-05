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

      assert %{entries: [first, second]} = Catalog.list_products(scope, %{"sort" => "name_asc"})

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

      assert %{page: 1, total_pages: 1} = Catalog.list_products(scope, %{"page" => "999"})
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
      assert product.master_variant.master
      assert product.variants == []
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} =
               Catalog.create_product(%{name: nil, status: nil, description: nil, slug: nil})
    end

    test "creates product-owned options without variants" do
      taxon = taxon_fixture()
      product_type = product_type_fixture()

      attrs = %{
        name: "Trail Shoe",
        status: :draft,
        primary_taxon_id: taxon.id,
        product_type_id: product_type.id,
        product_options: [
          %{
            name: "Size",
            values: [
              %{name: "8"},
              %{name: "9"}
            ]
          },
          %{
            name: "Color",
            values: [
              %{name: "Black"},
              %{name: "White"}
            ]
          }
        ]
      }

      assert {:ok, product} = Catalog.create_product(attrs)
      assert Enum.map(product.product_options, & &1.name) == ["Size", "Color"]
      assert product.master_variant.master
      assert product.variants == []
    end

    test "rejects duplicate product option names regardless of case" do
      taxon = taxon_fixture()
      product_type = product_type_fixture()

      attrs = %{
        name: "Trail Shoe",
        status: :draft,
        primary_taxon_id: taxon.id,
        product_type_id: product_type.id,
        product_options: [
          %{name: "Size", values: [%{name: "8"}]},
          %{name: "size", values: [%{name: "9"}]}
        ]
      }

      assert {:error, changeset} = Catalog.create_product(attrs)
      assert errors_on(changeset).product_options == [%{}, %{name: ["has already been taken"]}]
    end

    test "rejects duplicate product option value names regardless of case" do
      taxon = taxon_fixture()
      product_type = product_type_fixture()

      attrs = %{
        name: "Trail Shoe",
        status: :draft,
        primary_taxon_id: taxon.id,
        product_type_id: product_type.id,
        product_options: [
          %{name: "Size", values: [%{name: "Small"}, %{name: "small"}]}
        ]
      }

      assert {:error, changeset} = Catalog.create_product(attrs)

      assert errors_on(changeset).product_options == [
               %{values: [%{}, %{name: ["has already been taken"]}]}
             ]
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

    test "updates the master variant" do
      product = product_fixture(%{status: :draft, variants: []})

      assert {:ok, %Product{} = product} =
               Catalog.update_product(product, %{
                 master_variant: %{
                   id: product.master_variant.id,
                   sku: "tee-master",
                   price: Money.new(:USD, 20),
                   inventory_policy: :track_strict,
                   quantity_available: 5,
                   enabled: true
                 }
               })

      assert product.master_variant.sku == "tee-master"
      assert product.master_variant.price == Money.new(:USD, 20)
      assert product.master_variant.quantity_available == 5
      assert product.master_variant.enabled
    end

    test "changing product type does not rewrite product options" do
      product_type = product_type_fixture()
      replacement_product_type = product_type_fixture()

      product =
        product_with_options_fixture(
          [{"Size", ["S", "M"]}, {"Color", ["Black", "White"]}],
          %{product_type_id: product_type.id}
        )

      option_snapshot =
        Enum.map(product.product_options, fn product_option ->
          {product_option.name, Enum.map(product_option.values, & &1.name)}
        end)

      assert {:ok, product} =
               Catalog.update_product(product, %{product_type_id: replacement_product_type.id})

      assert product.product_type_id == replacement_product_type.id

      assert Enum.map(product.product_options, fn product_option ->
               {product_option.name, Enum.map(product_option.values, & &1.name)}
             end) == option_snapshot
    end

    test "rejects option changes once variants exist" do
      product = product_with_options_fixture([{"Size", ["S", "M"]}])

      assert {:error, changeset} =
               Catalog.update_product(product, %{
                 product_options: [
                   %{
                     id: List.first(product.product_options).id,
                     name: "Size",
                     values: [%{name: "L"}]
                   }
                 ]
               })

      assert errors_on(changeset).product_options == ["cannot be changed once variants exist"]
    end
  end

  describe "update_product_variants/2" do
    test "creates variant selections for persisted product options" do
      product = product_fixture(%{status: :draft, variants: []})

      assert {:ok, product} =
               Catalog.update_product(product, %{
                 product_options: [
                   %{
                     name: "Size",
                     values: [%{name: "8"}, %{name: "9"}]
                   },
                   %{
                     name: "Color",
                     values: [%{name: "Black"}, %{name: "White"}]
                   }
                 ]
               })

      [size_option, color_option] = product.product_options
      [small_value | _] = size_option.values
      [black_value | _] = color_option.values

      attrs = %{
        variants: [
          %{
            sku: "trail-shoe-8-black",
            price: Money.new(:USD, 80),
            inventory_policy: :track_strict,
            quantity_available: 10,
            enabled: true,
            variant_option_values: [
              %{product_option_id: size_option.id, product_option_value_id: small_value.id},
              %{product_option_id: color_option.id, product_option_value_id: black_value.id}
            ]
          }
        ]
      }

      assert {:ok, product} = Catalog.update_product_variants(product, attrs)

      assert Enum.map(product.variants, fn variant ->
               variant.option_values
               |> Enum.map(& &1.name)
               |> Enum.sort()
             end) == [["8", "Black"]]
    end

    test "rejects variants that do not cover every product option" do
      product = product_fixture(%{status: :draft, variants: []})

      assert {:ok, product} =
               Catalog.update_product(product, %{
                 product_options: [
                   %{name: "Size", values: [%{name: "8"}]},
                   %{name: "Color", values: [%{name: "Black"}]}
                 ]
               })

      [size_option | _] = product.product_options
      [small_value | _] = size_option.values

      attrs = %{
        variants: [
          %{
            sku: "trail-shoe-8",
            price: Money.new(:USD, 80),
            inventory_policy: :track_strict,
            quantity_available: 10,
            enabled: true,
            variant_option_values: [
              %{product_option_id: size_option.id, product_option_value_id: small_value.id}
            ]
          }
        ]
      }

      Harbor.TestRepo.query!("""
      SET CONSTRAINTS variants_option_values_variant_shape_check,
                      variants_variant_shape_check,
                      products_variant_shape_check IMMEDIATE
      """)

      assert {:error, changeset} = Catalog.update_product_variants(product, attrs)

      assert errors_on(changeset).variants == [
               %{variant_option_values: ["must cover all product options"]}
             ]
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
      taxon = taxon_fixture(%{})
      assert Catalog.get_taxon!(taxon.id) == taxon
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

      assert {:ok, taxon} = Catalog.create_taxon(admin_scope, valid_attrs)
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

      assert {:ok, taxon} = Catalog.update_taxon(admin_scope, taxon, update_attrs)
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

      assert taxon == Catalog.get_taxon!(taxon.id)
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
        Catalog.get_taxon!(taxon.id)
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
