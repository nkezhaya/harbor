defmodule Harbor.Catalog.ProductTaxon do
  @moduledoc false
  use Harbor.Schema

  alias Harbor.Catalog.{Product, Taxon}

  @primary_key false
  schema "product_taxons" do
    belongs_to :product, Product, primary_key: true
    belongs_to :taxon, Taxon, primary_key: true
    field :position, :integer, default: 0
  end

  @doc false
  def changeset(product_taxon, attrs) do
    product_taxon
    |> cast(attrs, [:product_id, :taxon_id, :position])
    |> validate_required([:product_id, :taxon_id, :position])
    |> assoc_constraint(:product)
    |> assoc_constraint(:taxon)
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
  end
end
