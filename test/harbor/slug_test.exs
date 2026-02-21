defmodule Harbor.SlugTest do
  use Harbor.DataCase, async: true
  import Harbor.CatalogFixtures

  alias Harbor.Catalog.Product
  alias Harbor.{Repo, Slug}

  doctest Slug

  describe "put_new_slug/2" do
    test "validates manual overrides" do
      product = product_fixture()

      product =
        product
        |> Product.changeset(%{slug: "override foo"})
        |> Repo.update!()

      assert product.slug == "override-foo"
    end

    test "adds a numeric suffix when a slug already exists" do
      name = "Duplicate Product"

      product_one = product_fixture(%{name: name})
      product_two = product_fixture(%{name: name})
      product_three = product_fixture(%{name: name})

      assert product_one.slug == "duplicate-product"
      assert product_two.slug == "duplicate-product-2"
      assert product_three.slug == "duplicate-product-3"
    end

    test "refreshes the slug when the source field changes" do
      product = product_fixture(%{name: "Original Product"})

      product =
        product
        |> Product.changeset(%{name: "Renamed Product"})
        |> Repo.update!()

      assert product.slug == "renamed-product"
    end
  end

  describe "to_slug/1" do
    test "accepts atoms" do
      assert Slug.to_slug(nil) == ""
      assert Slug.to_slug(true) == "true"
      assert Slug.to_slug(false) == "false"
      assert Slug.to_slug(:foo) == "foo"
    end
  end
end
