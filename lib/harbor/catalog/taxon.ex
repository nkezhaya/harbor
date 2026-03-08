defmodule Harbor.Catalog.Taxon do
  @moduledoc """
  A taxon is a node in Harbor's internal merchandising tree.

  Taxons are used for navigation and collection-style placement, not as the
  primary definition of what a product is.
  """
  use Harbor.Schema

  alias Harbor.Catalog.ProductTaxon
  alias Harbor.Slug

  @type t() :: %__MODULE__{}

  schema "taxons" do
    field :name, :string
    field :slug, :string
    field :position, :integer, default: 0
    field :parent_ids, {:array, :binary_id}, default: []

    belongs_to :parent, __MODULE__

    has_many :children, __MODULE__, foreign_key: :parent_id
    has_many :product_taxons, ProductTaxon
    has_many :products, through: [:product_taxons, :product]

    timestamps()
  end

  @doc false
  def changeset(taxon, attrs) do
    taxon
    |> cast(attrs, [:name, :slug, :position, :parent_id, :parent_ids])
    |> validate_required([:name, :position])
    |> Slug.put_new_slug(unique_by: __MODULE__)
    |> assoc_constraint(:parent)
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> check_constraint(:parent_id,
      name: :parent_cannot_be_self,
      message: "cannot be its own parent"
    )
    |> unique_constraint([:parent_id, :name])
    |> unique_constraint(:slug)
    |> unique_constraint([:parent_id, :position], name: :taxons_parent_id_position_unique)
  end
end
