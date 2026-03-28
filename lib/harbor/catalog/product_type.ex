defmodule Harbor.Catalog.ProductType do
  @moduledoc """
  A product type is Harbor's internal template for a kind of product.

  It carries lightweight classification and default tax information for that
  kind of item, and may still provide property templates.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{Product, ProductTypeProperty}
  alias Harbor.Slug
  alias Harbor.Tax.TaxCode

  @type t() :: %__MODULE__{}

  schema "product_types" do
    field :name, :string
    field :slug, :string

    belongs_to :tax_code, TaxCode

    has_many :products, Product
    has_many :product_type_properties, ProductTypeProperty, on_replace: :delete
    has_many :properties, through: [:product_type_properties, :property]

    timestamps()
  end

  @doc false
  def changeset(product_type, attrs) do
    product_type
    |> cast(attrs, [:name, :slug, :tax_code_id])
    |> validate_required([:name, :tax_code_id])
    |> Slug.put_new_slug(unique_by: __MODULE__)
    |> assoc_constraint(:tax_code)
    |> unique_constraint(:name)
    |> unique_constraint(:slug)
  end
end
