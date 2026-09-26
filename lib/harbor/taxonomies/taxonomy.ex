defmodule Harbor.Taxonomies.Taxonomy do
  @moduledoc """
  A named grouping of taxons, such as Categories, Departments, or Collections.

  Each taxon belongs to one taxonomy. Taxonomies do not determine storefront
  navigation or a product's primary taxon.
  """
  use Harbor.Schema

  alias Harbor.Slug
  alias Harbor.Taxonomies.Taxon

  @type t() :: %__MODULE__{}

  schema "taxonomies" do
    field :name, :string
    field :slug, :string
    field :position, :integer, default: 0

    has_many :taxons, Taxon

    timestamps()
  end

  @doc false
  def changeset(taxonomy, attrs) do
    taxonomy
    |> cast(attrs, [:name, :slug, :position])
    |> validate_required([:name, :position])
    |> Slug.put_new_slug(unique_by: __MODULE__)
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint(:name)
    |> unique_constraint(:slug)
    |> no_assoc_constraint(:taxons, message: "must be empty before it can be deleted")
  end
end
