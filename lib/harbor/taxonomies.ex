defmodule Harbor.Taxonomies do
  @moduledoc """
  Manages taxonomies and their taxon hierarchies.
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

  def update_taxon(%Scope{} = scope, %Taxon{} = taxon, attrs) do
    ensure_admin!(scope)

    taxon
    |> Taxon.changeset(attrs)
    |> Repo.update()
    |> preload_taxon_result()
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
