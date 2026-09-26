defmodule Harbor.TaxonomiesFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Harbor.Taxonomies` context.
  """
  alias Harbor.AccountsFixtures
  alias Harbor.Taxonomies

  def taxonomy_fixture(attrs \\ %{}) do
    scope = AccountsFixtures.admin_scope_fixture()
    attrs = Enum.into(attrs, %{name: "Taxonomy #{System.unique_integer([:positive])}"})
    {:ok, taxonomy} = Taxonomies.create_taxonomy(scope, attrs)
    taxonomy
  end

  def taxon_fixture(attrs \\ %{}) do
    scope = AccountsFixtures.admin_scope_fixture()

    attrs =
      attrs
      |> Enum.into(%{
        name: "some name-#{System.unique_integer([:positive])}",
        parent_ids: []
      })
      |> Map.put_new_lazy(:taxonomy_id, fn -> taxonomy_fixture().id end)

    {:ok, taxon} = Taxonomies.create_taxon(scope, attrs)

    taxon
  end
end
