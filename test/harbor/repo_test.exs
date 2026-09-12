defmodule Harbor.RepoTest do
  use Harbor.DataCase, async: true

  import Harbor.CatalogFixtures

  alias Harbor.Catalog.ProductType

  describe "paginate/2" do
    setup do
      product_types =
        for name <- ~w(Alpha Bravo Charlie Delta Echo) do
          product_type_fixture(%{name: name})
        end

      query = order_by(ProductType, asc: :name)

      [query: query, product_types: product_types]
    end

    test "uses default pagination for empty options", %{
      query: query,
      product_types: product_types
    } do
      assert Repo.paginate(query, []) == %{
               entries: product_types,
               page: 1,
               per_page: 20,
               total: 5,
               total_pages: 1
             }
    end

    test "accepts keyword options and returns the requested page", %{
      query: query,
      product_types: product_types
    } do
      assert %{entries: entries, page: 2, per_page: 2, total: 5, total_pages: 3} =
               Repo.paginate(query, page: 2, per_page: 2)

      assert entries == Enum.slice(product_types, 2, 2)
    end

    test "accepts map options", %{query: query, product_types: product_types} do
      assert %{entries: entries, page: 2, per_page: 2, total: 5, total_pages: 3} =
               Repo.paginate(query, %{page: 2, per_page: 2})

      assert entries == Enum.slice(product_types, 2, 2)
    end

    test "uses defaults for nil pagination values", %{
      query: query,
      product_types: product_types
    } do
      assert Repo.paginate(query, page: nil, per_page: nil) == %{
               entries: product_types,
               page: 1,
               per_page: 20,
               total: 5,
               total_pages: 1
             }
    end

    test "returns a partial final page", %{query: query, product_types: product_types} do
      assert %{entries: entries, page: 3, per_page: 2, total: 5, total_pages: 3} =
               Repo.paginate(query, page: 3, per_page: 2)

      assert entries == [List.last(product_types)]
    end

    test "does not add an extra page for an exact multiple", %{
      query: query,
      product_types: product_types
    } do
      assert %{entries: entries, page: 1, per_page: 5, total: 5, total_pages: 1} =
               Repo.paginate(query, per_page: 5)

      assert entries == product_types
    end

    test "clamps non-positive page numbers to the first page", %{
      query: query,
      product_types: product_types
    } do
      for page <- [0, -1] do
        assert %{entries: entries, page: 1, per_page: 2, total: 5, total_pages: 3} =
                 Repo.paginate(query, page: page, per_page: 2)

        assert entries == Enum.take(product_types, 2)
      end
    end

    test "clamps page numbers beyond the last page", %{
      query: query,
      product_types: product_types
    } do
      assert %{entries: entries, page: 3, per_page: 2, total: 5, total_pages: 3} =
               Repo.paginate(query, page: 999, per_page: 2)

      assert entries == [List.last(product_types)]
    end

    test "clamps non-positive page sizes to one", %{
      query: query,
      product_types: product_types
    } do
      for per_page <- [0, -1] do
        assert %{entries: entries, page: 1, per_page: 1, total: 5, total_pages: 5} =
                 Repo.paginate(query, per_page: per_page)

        assert entries == [List.first(product_types)]
      end
    end

    test "caps page sizes at 100", %{query: query, product_types: product_types} do
      assert %{entries: entries, page: 1, per_page: 100, total: 5, total_pages: 1} =
               Repo.paginate(query, per_page: 200)

      assert entries == product_types
    end

    test "preserves filtering, ordering, and selected fields" do
      query =
        ProductType
        |> where([product_type], product_type.name in ["Alpha", "Charlie", "Echo"])
        |> order_by(desc: :name)
        |> select([product_type], product_type.name)

      assert Repo.paginate(query, page: 2, per_page: 2) == %{
               entries: ["Alpha"],
               page: 2,
               per_page: 2,
               total: 3,
               total_pages: 2
             }
    end

    test "returns an empty first page when no rows match", %{query: query} do
      query = where(query, [product_type], product_type.name == "Missing")

      assert Repo.paginate(query, page: 999, per_page: 2) == %{
               entries: [],
               page: 1,
               per_page: 2,
               total: 0,
               total_pages: 1
             }
    end
  end
end
