defmodule Harbor.Constraints.TaxonomiesTest do
  use Harbor.DataCase, async: true

  import Harbor.TaxonomiesFixtures

  alias Harbor.Taxonomies.Taxon
  alias Harbor.TestRepo

  test "taxons_taxonomy_id_parent_id_position_unique is enforced by the database" do
    taxon = taxon_fixture()
    taxon_fixture(%{taxonomy_id: taxon.taxonomy_id, position: taxon.position})

    error =
      assert_raise Postgrex.Error, fn ->
        TestRepo.query!("SET CONSTRAINTS taxons_taxonomy_id_parent_id_position_unique IMMEDIATE")
      end

    assert error.postgres.constraint == "taxons_taxonomy_id_parent_id_position_unique"
  end

  test "taxons_parent_in_taxonomy is enforced by the database" do
    taxon = taxon_fixture()
    other_parent = taxon_fixture()

    error =
      assert_raise Postgrex.Error, fn ->
        Taxon
        |> where([t], t.id == ^taxon.id)
        |> TestRepo.update_all(set: [parent_id: other_parent.id])
      end

    assert error.postgres.constraint == "taxons_parent_in_taxonomy"
  end
end
