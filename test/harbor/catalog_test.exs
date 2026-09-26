defmodule Harbor.CatalogTest do
  use Harbor.DataCase, async: true
  import Harbor.CatalogFixtures

  alias Harbor.Accounts.Scope
  alias Harbor.AccountsFixtures
  alias Harbor.Catalog
  alias Harbor.Catalog.{Product, ProductImage, Taxon, Taxonomy}
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

    test "filters by taxon slug across the selected subtree", %{scope: scope} do
      suffix = System.unique_integer([:positive])
      parent = taxon_fixture(%{name: "Parent Taxon #{suffix}"})

      child =
        taxon_fixture(%{
          name: "Child Taxon #{suffix}",
          taxonomy_id: parent.taxonomy_id,
          parent_id: parent.id,
          parent_ids: [parent.id]
        })

      direct = product_fixture(%{name: "A Direct Product #{suffix}", primary_taxon_id: parent.id})

      descendant =
        product_fixture(%{name: "B Descendant Product #{suffix}", primary_taxon_id: child.id})

      _other = product_fixture(%{name: "C Other Product #{suffix}"})

      assert %{entries: products, total: 2} =
               Catalog.list_products(scope, %{"taxon" => parent.slug, "sort" => "name_asc"})

      assert Enum.map(products, & &1.id) == [direct.id, descendant.id]
    end

    test "returns descendant products when the selected parent has no direct products", %{
      scope: scope
    } do
      suffix = System.unique_integer([:positive])
      parent = taxon_fixture(%{name: "Empty Parent #{suffix}"})

      child =
        taxon_fixture(%{
          name: "Descendant Taxon #{suffix}",
          taxonomy_id: parent.taxonomy_id,
          parent_id: parent.id,
          parent_ids: [parent.id]
        })

      product =
        product_fixture(%{name: "Only Descendant Product #{suffix}", primary_taxon_id: child.id})

      assert %{entries: [matched], total: 1} =
               Catalog.list_products(scope, %{"taxon" => parent.slug})

      assert matched.id == product.id
    end

    test "does not duplicate a product attached to both an ancestor and descendant taxon", %{
      scope: scope
    } do
      suffix = System.unique_integer([:positive])
      parent = taxon_fixture(%{name: "Ancestor Taxon #{suffix}"})

      child =
        taxon_fixture(%{
          name: "Nested Taxon #{suffix}",
          taxonomy_id: parent.taxonomy_id,
          parent_id: parent.id,
          parent_ids: [parent.id]
        })

      product =
        product_fixture(%{
          name: "Shared Product #{suffix}",
          primary_taxon_id: parent.id,
          taxon_ids: [parent.id, child.id]
        })

      assert %{entries: [matched], total: 1} =
               Catalog.list_products(scope, %{"taxon" => parent.slug})

      assert matched.id == product.id
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

    test "paginates tied sort values deterministically", %{scope: scope} do
      products =
        for i <- 1..7 do
          product_fixture(%{name: "Tied Product #{i}"})
        end

      ids = Enum.map(products, & &1.id)
      tied_at = ~U[2024-01-01 00:00:00Z]

      Enum.each(ids, fn id ->
        Repo.update_all(from(p in Product, where: p.id == ^id), set: [inserted_at: tied_at])
      end)

      expected_ids = Enum.sort(ids, :desc)

      assert %{entries: page_one} =
               Catalog.list_products(scope, %{"per_page" => "5", "page" => "1"})

      assert %{entries: page_two} =
               Catalog.list_products(scope, %{"per_page" => "5", "page" => "2"})

      assert Enum.map(page_one, & &1.id) == Enum.take(expected_ids, 5)
      assert Enum.map(page_two, & &1.id) == Enum.drop(expected_ids, 5)
    end

    test "searches by name, description, and SKU", %{scope: scope} do
      suffix = System.unique_integer([:positive])
      name_match = product_fixture(%{name: "Wool Blanket"})

      description_match =
        product_fixture(%{name: "Clay Bowl", description: "Finished with glaze-#{suffix}."})

      sku_match =
        product_fixture(%{
          name: "Canvas Tote",
          variants: [
            %{
              sku: "RS-#{suffix}-CANVAS",
              price: Money.new(:USD, 40),
              inventory_policy: :track_strict,
              quantity_available: 10,
              enabled: true
            }
          ]
        })

      product_fixture(%{name: "Cotton Shirt"})

      assert %{entries: [product]} = Catalog.list_products(scope, %{"search" => "wool"})
      assert product.id == name_match.id

      assert %{entries: [product]} =
               Catalog.list_products(scope, %{"search" => "glaze-#{suffix}"})

      assert product.id == description_match.id

      assert %{entries: [product]} =
               Catalog.list_products(scope, %{"search" => "#{suffix}-CANVAS"})

      assert product.id == sku_match.id
    end

    test "orders search results by relevance", %{scope: scope} do
      description_match =
        product_fixture(%{name: "Aardvark Bowl", description: "Soft wool finish"})

      name_match = product_fixture(%{name: "Zebra Wool Blanket"})

      assert %{entries: [product | _]} =
               Catalog.list_products(scope, %{"search" => "wool", "sort" => "name_asc"})

      assert product.id == name_match.id
      assert product.id != description_match.id
    end

    test "searches SKUs without caring about spaces or dashes", %{scope: scope} do
      suffix = System.unique_integer([:positive])

      products =
        ["8502-C-#{suffix}", "8502 C #{suffix}", "8502C#{suffix}"]
        |> Enum.map(fn sku ->
          product_fixture(%{
            name: "SKU product #{System.unique_integer([:positive])}",
            variants: [
              %{
                sku: sku,
                price: Money.new(:USD, 40),
                inventory_policy: :track_strict,
                quantity_available: 10,
                enabled: true
              }
            ]
          })
        end)

      expected_ids = products |> Enum.map(& &1.id) |> Enum.sort()

      for search <- ["8502-c-#{suffix}", "8502c#{suffix}", "8502 c #{suffix}"] do
        assert %{entries: entries} = Catalog.list_products(scope, %{"search" => search})
        assert entries |> Enum.map(& &1.id) |> Enum.sort() == expected_ids
      end
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

    test "preloads the first ready image per product and leaves products without ready images empty",
         %{
           scope: scope
         } do
      alpha = product_fixture(%{name: "Alpha"})
      beta = product_fixture(%{name: "Beta"})
      gamma = product_fixture(%{name: "Gamma"})

      product_image_fixture(%{product_id: alpha.id, position: 0})

      alpha_first_ready =
        product_image_fixture(%{product_id: alpha.id, status: :ready, position: 1})

      _alpha_second_ready =
        product_image_fixture(%{product_id: alpha.id, status: :ready, position: 2})

      beta_first_ready =
        product_image_fixture(%{product_id: beta.id, status: :ready, position: 0})

      _beta_second_ready =
        product_image_fixture(%{product_id: beta.id, status: :ready, position: 1})

      product_image_fixture(%{product_id: gamma.id, position: 0})

      assert %{entries: [alpha_result, beta_result, gamma_result]} =
               Catalog.list_products(scope, %{"sort" => "name_asc"})

      assert alpha_result.id == alpha.id
      assert Enum.map(alpha_result.images, & &1.id) == [alpha_first_ready.id]
      assert Enum.map(alpha_result.images, & &1.status) == [:ready]
      assert Enum.map(alpha_result.images, & &1.position) == [1]

      assert beta_result.id == beta.id
      assert Enum.map(beta_result.images, & &1.id) == [beta_first_ready.id]
      assert Enum.map(beta_result.images, & &1.status) == [:ready]
      assert Enum.map(beta_result.images, & &1.position) == [0]

      assert gamma_result.id == gamma.id
      assert gamma_result.images == []
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

    test "creates an active simple product with an enabled master variant" do
      taxon = taxon_fixture()
      product_type = product_type_fixture()

      attrs = %{
        "name" => "Active simple product",
        "status" => "active",
        "primary_taxon_id" => taxon.id,
        "taxon_ids" => [taxon.id],
        "product_type_id" => product_type.id,
        "master_variant" => %{"price" => "25.00"}
      }

      assert {:ok, product} = Catalog.create_product(attrs)
      assert product.status == :active
      assert product.master_variant.enabled
      assert product.master_variant.price == Money.new(:USD, "25.00")
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

    test "enables the master variant when activating a simple product" do
      product = product_fixture(%{status: :draft, variants: []})
      refute product.master_variant.enabled

      assert {:ok, product} = Catalog.update_product(product, %{status: :active})
      assert product.status == :active
      assert product.master_variant.enabled
    end

    test "disables the master variant when adding options" do
      product = product_fixture()
      assert product.master_variant.enabled

      assert {:ok, product} =
               Catalog.update_product(product, %{
                 status: :draft,
                 product_options: [%{name: "Size", values: [%{name: "Small"}]}]
               })

      assert product.product_options != []
      refute product.master_variant.enabled
    end

    test "rejects activating an optioned product without an enabled variant" do
      product =
        product_fixture(%{
          status: :draft,
          variants: [],
          product_options: [%{name: "Size", values: [%{name: "Small"}]}]
        })

      assert {:error, changeset} = Catalog.update_product(product, %{status: :active})
      assert errors_on(changeset).status == ["cannot be active without a purchasable variant"]
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

    test "rejects disabling the last enabled variant of an active product" do
      product = product_with_options_fixture([{"Size", ["Small"]}])
      [variant] = product.variants

      assert {:error, changeset} =
               Catalog.update_product_variants(product, %{
                 variants: [%{id: variant.id, enabled: false}]
               })

      assert errors_on(changeset).variants == [
               "must include a purchasable variant while the product is active"
             ]
    end
  end

  describe "delete_product/1" do
    test "deletes the product" do
      product = product_fixture()

      assert {:ok, %Product{}} = Catalog.delete_product(product)

      Harbor.TestRepo.query!("SET CONSTRAINTS product_variant_shape_validation_check IMMEDIATE")

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

  describe "list_taxonomies/0" do
    test "orders taxonomies by position and name" do
      last = taxonomy_fixture(%{name: "Last", position: 1})
      second = taxonomy_fixture(%{name: "Departments"})
      first = taxonomy_fixture(%{name: "Categories"})

      assert Catalog.list_taxonomies() == [first, second, last]
    end
  end

  describe "get_taxonomy!/1" do
    test "returns a taxonomy" do
      taxonomy = taxonomy_fixture()
      assert Catalog.get_taxonomy!(taxonomy.id) == taxonomy
    end
  end

  describe "create_taxonomy/2" do
    test "creates a taxonomy and derives its slug" do
      assert {:ok, taxonomy} =
               Catalog.create_taxonomy(Scope.for_system(), %{
                 name: "Product Categories",
                 position: 2
               })

      assert taxonomy.name == "Product Categories"
      assert taxonomy.slug == "product-categories"
      assert taxonomy.position == 2
    end

    test "validates required fields" do
      assert {:error, changeset} =
               Catalog.create_taxonomy(Scope.for_system(), %{name: "", position: nil})

      assert errors_on(changeset).name == ["can't be blank"]
      assert errors_on(changeset).position == ["can't be blank"]
    end

    test "rejects duplicate names" do
      taxonomy = taxonomy_fixture()

      assert {:error, changeset} =
               Catalog.create_taxonomy(Scope.for_system(), %{name: taxonomy.name})

      assert errors_on(changeset).name == ["has already been taken"]
    end

    test "rejects negative positions" do
      assert {:error, changeset} =
               Catalog.create_taxonomy(Scope.for_system(), %{name: "Categories", position: -1})

      assert errors_on(changeset).position == ["must be greater than or equal to 0"]
    end

    test "requires an admin scope" do
      scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Catalog.create_taxonomy(scope, %{name: "Categories"})
      end
    end
  end

  describe "update_taxonomy/3" do
    test "updates taxonomy metadata without changing taxon ownership" do
      taxonomy = taxonomy_fixture()
      taxon = taxon_fixture(%{taxonomy_id: taxonomy.id})

      assert {:ok, updated} =
               Catalog.update_taxonomy(Scope.for_system(), taxonomy, %{
                 name: "Collections",
                 slug: "curated-collections",
                 position: 3
               })

      assert updated.name == "Collections"
      assert updated.slug == "curated-collections"
      assert updated.position == 3
      assert Catalog.get_taxon!(taxon.id).taxonomy_id == taxonomy.id
    end

    test "does not persist invalid changes" do
      taxonomy = taxonomy_fixture()

      assert {:error, changeset} =
               Catalog.update_taxonomy(Scope.for_system(), taxonomy, %{name: ""})

      assert errors_on(changeset).name == ["can't be blank"]
      assert Catalog.get_taxonomy!(taxonomy.id) == taxonomy
    end

    test "requires an admin scope" do
      taxonomy = taxonomy_fixture()
      scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Catalog.update_taxonomy(scope, taxonomy, %{name: "Collections"})
      end
    end
  end

  describe "delete_taxonomy/2" do
    test "deletes an empty taxonomy" do
      taxonomy = taxonomy_fixture()
      assert {:ok, %Taxonomy{}} = Catalog.delete_taxonomy(Scope.for_system(), taxonomy)
      refute Repo.get(Taxonomy, taxonomy.id)
    end

    test "does not delete a taxonomy containing taxons" do
      taxonomy = taxonomy_fixture()
      taxon = taxon_fixture(%{taxonomy_id: taxonomy.id})

      assert {:error, changeset} = Catalog.delete_taxonomy(Scope.for_system(), taxonomy)
      assert errors_on(changeset).taxons == ["must be empty before it can be deleted"]
      assert Repo.get(Taxonomy, taxonomy.id)
      assert Repo.get(Taxon, taxon.id)
    end

    test "requires an admin scope" do
      taxonomy = taxonomy_fixture()
      scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Catalog.delete_taxonomy(scope, taxonomy)
      end
    end
  end

  describe "change_taxonomy/3" do
    test "returns a changeset" do
      taxonomy = taxonomy_fixture()

      assert %Ecto.Changeset{} =
               Catalog.change_taxonomy(Scope.for_system(), taxonomy, %{name: "Collections"})
    end

    test "requires an admin scope" do
      taxonomy = taxonomy_fixture()
      scope = AccountsFixtures.user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Catalog.change_taxonomy(scope, taxonomy)
      end
    end
  end

  describe "list_root_taxons/0" do
    test "lists roots across all taxonomies" do
      first = taxon_fixture(%{position: 0})
      second = taxon_fixture(%{position: 1})
      _child = taxon_fixture(%{taxonomy_id: first.taxonomy_id, parent_id: first.id})

      assert Enum.map(Catalog.list_root_taxons(), & &1.id) == [first.id, second.id]
    end
  end

  describe "list_taxons/0" do
    test "returns all taxons" do
      taxon = taxon_fixture(%{})

      assert Catalog.list_taxons() == [taxon]
    end
  end

  describe "list_taxons/1" do
    test "only returns taxons belonging to the taxonomy, ordered by position" do
      taxonomy = taxonomy_fixture()
      last = taxon_fixture(%{taxonomy_id: taxonomy.id, position: 1})
      first = taxon_fixture(%{taxonomy_id: taxonomy.id})
      _other = taxon_fixture()

      assert Catalog.list_taxons(taxonomy.id) == [first, last]
    end
  end

  describe "get_taxon!/1" do
    test "returns the taxon with given id" do
      taxon = taxon_fixture(%{})
      assert Catalog.get_taxon!(taxon.id) == taxon
    end
  end

  describe "get_taxon!/2" do
    test "only retrieves a taxon inside its owning taxonomy" do
      taxonomy = taxonomy_fixture()
      taxon = taxon_fixture(%{taxonomy_id: taxonomy.id})
      other = taxon_fixture()

      assert Catalog.get_taxon!(taxonomy.id, taxon.id) == taxon

      assert_raise Ecto.NoResultsError, fn ->
        Catalog.get_taxon!(taxonomy.id, other.id)
      end
    end
  end

  describe "create_taxon/2" do
    test "preloads its taxonomy" do
      taxonomy = taxonomy_fixture()

      assert {:ok, taxon} =
               Catalog.create_taxon(Scope.for_system(), %{
                 name: "Shirts",
                 taxonomy_id: taxonomy.id
               })

      assert taxon.taxonomy == taxonomy
    end

    test "requires a taxonomy ID" do
      assert {:error, changeset} = Catalog.create_taxon(Scope.for_system(), %{name: "Shirts"})

      assert errors_on(changeset).taxonomy_id == ["can't be blank"]
    end

    test "rejects a nonexistent taxonomy ID" do
      taxonomy = taxonomy_fixture()
      {:ok, _taxonomy} = Catalog.delete_taxonomy(Scope.for_system(), taxonomy)

      assert {:error, changeset} =
               Catalog.create_taxon(Scope.for_system(), %{
                 name: "Shirts",
                 taxonomy_id: taxonomy.id
               })

      assert errors_on(changeset).taxonomy == ["does not exist"]
    end

    test "allows a parent from the same taxonomy" do
      parent = taxon_fixture()

      assert {:ok, child} =
               Catalog.create_taxon(Scope.for_system(), %{
                 name: "Shirts",
                 taxonomy_id: parent.taxonomy_id,
                 parent_id: parent.id,
                 parent_ids: [parent.id]
               })

      assert child.parent_id == parent.id
      assert child.taxonomy_id == parent.taxonomy_id
    end

    test "rejects a parent from another taxonomy" do
      parent = taxon_fixture()
      taxonomy = taxonomy_fixture()

      assert {:error, changeset} =
               Catalog.create_taxon(Scope.for_system(), %{
                 name: "Shirts",
                 taxonomy_id: taxonomy.id,
                 parent_id: parent.id
               })

      assert errors_on(changeset).parent_id == ["must belong to the same taxonomy"]
    end

    test "allows matching root names and positions in separate taxonomies but keeps slugs global" do
      first = taxon_fixture(%{name: "Clothing"})
      second = taxon_fixture(%{name: "Clothing"})

      assert first.position == second.position
      refute first.taxonomy_id == second.taxonomy_id
      refute first.slug == second.slug
    end

    test "rejects matching root names within a taxonomy" do
      taxon = taxon_fixture(%{name: "Clothing"})

      assert {:error, changeset} =
               Catalog.create_taxon(Scope.for_system(), %{
                 name: "Clothing",
                 taxonomy_id: taxon.taxonomy_id,
                 position: 1
               })

      assert errors_on(changeset).name == ["has already been taken"]
    end

    test "with valid data creates a taxon" do
      admin_scope = AccountsFixtures.admin_scope_fixture()

      valid_attrs = %{
        name: "some name",
        position: 42,
        slug: "some slug",
        taxonomy_id: taxonomy_fixture().id
      }

      assert {:ok, taxon} = Catalog.create_taxon(admin_scope, valid_attrs)
      assert taxon.name == "some name"
      assert taxon.position == 42
      assert taxon.slug == "some-slug"
      assert taxon.taxonomy_id == valid_attrs.taxonomy_id
    end

    test "with invalid data returns error changeset" do
      admin_scope = AccountsFixtures.admin_scope_fixture()

      assert {:error, %Ecto.Changeset{}} =
               Catalog.create_taxon(admin_scope, %{
                 name: nil,
                 position: nil,
                 slug: nil,
                 taxonomy_id: taxonomy_fixture().id
               })
    end

    test "raises for non-admin scopes" do
      user_scope = AccountsFixtures.user_scope_fixture()
      taxonomy = taxonomy_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Catalog.create_taxon(user_scope, %{name: "foo", taxonomy_id: taxonomy.id})
      end
    end
  end

  describe "update_taxon/3" do
    test "does not accept changes to taxonomy ownership" do
      taxon = taxon_fixture()
      other = taxonomy_fixture()

      assert {:ok, updated} =
               Catalog.update_taxon(Scope.for_system(), taxon, %{taxonomy_id: other.id})

      assert updated.taxonomy_id == taxon.taxonomy_id
    end

    test "rejects reparenting into a different taxonomy" do
      taxon = taxon_fixture()
      other_parent = taxon_fixture()

      assert {:error, changeset} =
               Catalog.update_taxon(Scope.for_system(), taxon, %{parent_id: other_parent.id})

      assert errors_on(changeset).parent_id == ["must belong to the same taxonomy"]
      refute Catalog.get_taxon!(taxon.id).parent_id
    end

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
    test "does not delete a taxon with children" do
      parent = taxon_fixture()
      child = taxon_fixture(%{taxonomy_id: parent.taxonomy_id, parent_id: parent.id})

      assert {:error, changeset} = Catalog.delete_taxon(Scope.for_system(), parent)
      assert errors_on(changeset).children == ["are still associated with this entry"]
      assert Repo.get(Taxon, child.id)
    end

    test "does not delete a product's primary taxon" do
      product = product_fixture()
      taxon = Catalog.get_taxon!(product.primary_taxon_id)

      assert {:error, %Ecto.Changeset{}} = Catalog.delete_taxon(Scope.for_system(), taxon)
      assert Repo.get(Taxon, taxon.id)
    end

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
