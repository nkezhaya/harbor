defmodule Harbor.Catalog.ProductType do
  @moduledoc """
  A product type is Harbor's internal template for a kind of product.

  It tells the catalog which option dimensions and descriptive properties
  usually apply, and it carries the default tax classification for that type of
  item.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{Product, ProductTypeOptionType, ProductTypeProperty}
  alias Harbor.Slug
  alias Harbor.Tax.TaxCode

  @type t() :: %__MODULE__{}

  schema "product_types" do
    field :name, :string
    field :slug, :string

    belongs_to :tax_code, TaxCode

    has_many :products, Product
    has_many :product_type_option_types, ProductTypeOptionType, on_replace: :delete
    has_many :option_types, through: [:product_type_option_types, :option_type]
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
