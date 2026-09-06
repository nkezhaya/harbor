defmodule Harbor.Constraints.CatalogTest do
  use Harbor.DataCase, async: true

  import Harbor.CatalogFixtures

  alias Harbor.Catalog
  alias Harbor.Catalog.{Product, Variant}
  alias Harbor.TestRepo

  test "product_options_must_have_values is enforced by the database" do
    product = product_fixture(%{status: :draft, variants: []})

    error =
      assert_raise Postgrex.Error, fn ->
        TestRepo.transact(fn ->
          product
          |> Product.changeset(%{
            product_options: [
              %{name: "Size", values: []}
            ]
          })
          |> TestRepo.update!()

          TestRepo.query!("SET CONSTRAINTS product_variant_shape_validation_check IMMEDIATE")
        end)
      end

    assert error.postgres.constraint == "product_options_must_have_values"
  end

  test "active_products_must_have_purchasable_variant is enforced for simple products" do
    product = product_fixture(%{status: :draft, variants: []})

    error =
      assert_raise Postgrex.Error, fn ->
        TestRepo.transact(fn ->
          product
          |> Product.changeset(%{status: :active})
          |> TestRepo.update!()

          TestRepo.query!("SET CONSTRAINTS product_variant_shape_validation_check IMMEDIATE")
        end)
      end

    assert error.postgres.constraint == "active_products_must_have_purchasable_variant"
  end

  test "active_products_must_have_purchasable_variant is enforced for optioned products" do
    product = product_with_options_fixture([{"Size", ["S"]}], %{status: :draft})

    error =
      assert_raise Postgrex.Error, fn ->
        TestRepo.transact(fn ->
          Variant
          |> where([v], v.product_id == ^product.id and not v.master)
          |> TestRepo.update_all(set: [enabled: false])

          product
          |> Product.changeset(%{status: :active})
          |> TestRepo.update!()

          TestRepo.query!("SET CONSTRAINTS product_variant_shape_validation_check IMMEDIATE")
        end)
      end

    assert error.postgres.constraint == "active_products_must_have_purchasable_variant"
  end

  test "variants_unique_option_combination is enforced by the database" do
    product = product_fixture(%{status: :draft, variants: []})

    assert {:ok, product} =
             Catalog.update_product(product, %{
               product_options: [%{name: "Size", values: [%{name: "S"}]}]
             })

    [size_option] = product.product_options
    [small_value] = size_option.values

    variant_attrs = %{
      price: Money.new(:USD, 40),
      inventory_policy: :track_strict,
      quantity_available: 10,
      enabled: true,
      variant_option_values: [
        %{
          product_option_id: size_option.id,
          product_option_value_id: small_value.id
        }
      ]
    }

    assert {:ok, _product} =
             Catalog.update_product_variants(product, %{
               variants: [
                 Map.put(variant_attrs, :sku, "size-small-one"),
                 Map.put(variant_attrs, :sku, "size-small-two")
               ]
             })

    error =
      assert_raise Postgrex.Error, fn ->
        TestRepo.query!("SET CONSTRAINTS product_variant_shape_validation_check IMMEDIATE")
      end

    assert error.postgres.constraint == "variants_unique_option_combination"
  end
end
