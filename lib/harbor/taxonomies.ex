defmodule Harbor.Taxonomies do
  @moduledoc """
  Manages taxonomies and their taxon hierarchies. Hierarchy writes through this
  context derive ancestry and update descendants atomically.
  """
  import Ecto.Query
  import Harbor.Authorization

  alias Harbor.Accounts.Scope
  alias Harbor.Repo
  alias Harbor.Taxonomies.{Taxon, Taxonomy}

  ## Taxonomies

  def list_taxonomies do
    Taxonomy
    |> order_by(asc: :position, asc: :name)
    |> Repo.all()
  end

  def get_taxonomy!(id) do
    Repo.get!(Taxonomy, id)
  end

  def create_taxonomy(%Scope{} = scope, attrs) do
    ensure_admin!(scope)

    %Taxonomy{}
    |> Taxonomy.changeset(attrs)
    |> Repo.insert()
  end

  def update_taxonomy(%Scope{} = scope, %Taxonomy{} = taxonomy, attrs) do
    ensure_admin!(scope)

    taxonomy
    |> Taxonomy.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes an empty taxonomy. Returns an error changeset if it still owns taxons.
  """
  def delete_taxonomy(%Scope{} = scope, %Taxonomy{} = taxonomy) do
    ensure_admin!(scope)

    taxonomy
    |> Taxonomy.changeset(%{})
    |> Repo.delete()
  end

  def change_taxonomy(%Scope{} = scope, %Taxonomy{} = taxonomy, attrs \\ %{}) do
    ensure_admin!(scope)
    Taxonomy.changeset(taxonomy, attrs)
  end

  ## Taxons

  def list_root_taxons do
    Taxon
    |> where([taxon], is_nil(taxon.parent_id))
    |> order_by(asc: :position, asc: :name)
    |> Repo.all()
  end

  def list_taxons do
    Taxon
    |> order_by(asc: :position, asc: :name)
    |> preload([:taxonomy, :parent])
    |> Repo.all()
  end

  @doc """
  Lists taxons for the given taxonomy ID ordered by position and name, with
  their taxonomy and parent preloaded.
  """
  def list_taxons(taxonomy_id) do
    Taxon
    |> where([taxon], taxon.taxonomy_id == ^taxonomy_id)
    |> order_by(asc: :position, asc: :name)
    |> preload([:taxonomy, :parent])
    |> Repo.all()
  end

  def get_taxon!(id) do
    Taxon
    |> preload([:taxonomy, :parent])
    |> Repo.get!(id)
  end

  @doc """
  Gets a taxon belonging to the given taxonomy ID. Raises `Ecto.NoResultsError`
  when the taxon does not exist or belongs to another taxonomy.
  """
  def get_taxon!(taxonomy_id, id) do
    Taxon
    |> where([taxon], taxon.taxonomy_id == ^taxonomy_id)
    |> preload([:taxonomy, :parent])
    |> Repo.get!(id)
  end

  @doc """
  Creates a taxon. Requires an admin or system scope.
  """
  def create_taxon(%Scope{} = scope, attrs) do
    ensure_admin!(scope)

    %Taxon{}
    |> Taxon.create_changeset(attrs)
    |> Repo.insert()
    |> preload_taxon_result()
  end

  @doc """
  Updates a taxon. Changing its parent also updates all descendant ancestry paths
  in the same transaction. Returns an error changeset for a move beneath itself
  or one of its descendants.
  """
  def update_taxon(%Scope{} = scope, %Taxon{} = taxon, attrs) do
    ensure_admin!(scope)

    Repo.transact(fn ->
      changeset = Taxon.changeset(taxon, attrs)

      case Repo.update(changeset) do
        {:ok, updated} when updated.parent_id != taxon.parent_id ->
          update_descendant_paths(updated)
          {:ok, updated}

        result ->
          result
      end
    end)
    |> preload_taxon_result()
  end

  defp update_descendant_paths(taxon) do
    parent_ids = taxon.parent_ids ++ [taxon.id]

    children =
      Taxon
      |> where([child], child.parent_id == ^taxon.id)
      |> select([child], %{
        id: child.id,
        parent_ids: type(^parent_ids, {:array, :binary_id})
      })

    descendants =
      Taxon
      |> join(:inner, [child], parent in "descendants", on: child.parent_id == parent.id)
      |> select([child, parent], %{
        id: child.id,
        parent_ids: fragment("array_append(?, ?)", parent.parent_ids, parent.id)
      })

    subtree = union_all(children, ^descendants)

    Taxon
    |> recursive_ctes(true)
    |> with_cte("descendants", as: ^subtree)
    |> join(:inner, [taxon], descendant in "descendants", on: taxon.id == descendant.id)
    |> update([_taxon, descendant],
      set: [parent_ids: descendant.parent_ids, updated_at: ^taxon.updated_at]
    )
    |> Repo.update_all([])
  end

  defp preload_taxon_result({:ok, taxon}) do
    {:ok, Repo.preload(taxon, [:taxonomy, :parent], force: true)}
  end

  defp preload_taxon_result(error) do
    error
  end

  def delete_taxon(%Scope{} = scope, %Taxon{} = taxon) do
    ensure_admin!(scope)

    taxon
    |> Taxon.delete_changeset()
    |> Repo.delete()
  end

  def change_taxon(%Scope{} = scope, %Taxon{} = taxon, attrs \\ %{}) do
    ensure_admin!(scope)
    Taxon.changeset(taxon, attrs)
  end
end
