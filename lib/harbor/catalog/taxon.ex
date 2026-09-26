defmodule Harbor.Catalog.Taxon do
  @moduledoc """
  A taxon is a merchandising node owned by a `Harbor.Catalog.Taxonomy`.

  Parent and child taxons belong to the same taxonomy. Taxons are used for
  navigation and collection-style placement, not as the primary definition of
  what a product is.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{ProductTaxon, Taxonomy}
  alias Harbor.Slug

  @type t() :: %__MODULE__{}

  schema "taxons" do
    field :name, :string
    field :slug, :string
    field :position, :integer, default: 0
    field :parent_ids, {:array, :binary_id}, default: []

    belongs_to :taxonomy, Taxonomy
    belongs_to :parent, __MODULE__

    has_many :children, __MODULE__, foreign_key: :parent_id
    has_many :product_taxons, ProductTaxon
    has_many :products, through: [:product_taxons, :product]

    timestamps()
  end

  @doc false
  def create_changeset(taxon, attrs) do
    taxon
    |> cast(attrs, [:taxonomy_id])
    |> changeset(attrs)
  end

  @doc false
  def changeset(taxon, attrs) do
    taxon
    |> cast(attrs, [:name, :slug, :position, :parent_id, :parent_ids])
    |> validate_required([:taxonomy_id, :name, :position])
    |> Slug.put_new_slug(unique_by: __MODULE__)
    |> assoc_constraint(:taxonomy)
    |> foreign_key_constraint(:parent_id,
      name: :taxons_parent_in_taxonomy,
      message: "must belong to the same taxonomy"
    )
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> check_constraint(:parent_id,
      name: :parent_cannot_be_self,
      message: "cannot be its own parent"
    )
    |> unique_constraint(:name, name: :taxons_taxonomy_id_parent_id_name_index)
    |> unique_constraint(:slug)
    |> unique_constraint(:position, name: :taxons_taxonomy_id_parent_id_position_unique)
  end

  @doc false
  def delete_changeset(taxon) do
    taxon
    |> change()
    |> no_assoc_constraint(:children, name: :taxons_parent_in_taxonomy)
    |> foreign_key_constraint(:id, name: :products_primary_taxon_id_fkey)
  end
end
