defmodule Harbor.Constraints.CatalogTest do
  use Harbor.DataCase, async: true

  import Harbor.CatalogFixtures

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

          TestRepo.query!("SET CONSTRAINTS product_options_variant_shape_check IMMEDIATE")
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

          TestRepo.query!("SET CONSTRAINTS products_variant_shape_check IMMEDIATE")
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

          TestRepo.query!(
            "SET CONSTRAINTS variants_variant_shape_check, products_variant_shape_check IMMEDIATE"
          )
        end)
      end

    assert error.postgres.constraint == "active_products_must_have_purchasable_variant"
  end
end
