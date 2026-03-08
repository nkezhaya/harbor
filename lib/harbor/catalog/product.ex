defmodule Harbor.Catalog.Product do
  @moduledoc """
  A product is the shared catalog record that customers recognize.

  It holds the product's descriptive data, media, merchandising placement, and
  the variants that can actually be purchased.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{
    Brand,
    ProductImage,
    ProductOptionType,
    ProductOptionValue,
    ProductPropertyValue,
    ProductTaxon,
    ProductType,
    Taxon,
    Variant
  }

  alias Harbor.Slug
  alias Harbor.Tax.TaxCode

  @type t() :: %__MODULE__{}

  schema "products" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :status, Ecto.Enum, values: [:draft, :active, :archived], default: :draft
    field :physical_product, :boolean, default: true

    belongs_to :brand, Brand
    belongs_to :product_type, ProductType
    belongs_to :primary_taxon, Taxon
    belongs_to :tax_code, TaxCode
    belongs_to :default_variant, Variant, foreign_key: :default_variant_id

    has_many :images, ProductImage, preload_order: [:position], on_replace: :delete
    has_many :product_taxons, ProductTaxon, preload_order: [:position], on_replace: :delete
    has_many :taxons, through: [:product_taxons, :taxon]

    has_many :product_option_types, ProductOptionType,
      preload_order: [:position],
      on_replace: :delete

    has_many :option_types, through: [:product_option_types, :option_type]
    has_many :product_option_values, ProductOptionValue, on_replace: :delete
    has_many :option_values, through: [:product_option_values, :option_value]
    has_many :product_property_values, ProductPropertyValue, on_replace: :delete
    has_many :variants, Variant, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [
      :name,
      :slug,
      :description,
      :status,
      :physical_product,
      :brand_id,
      :product_type_id,
      :primary_taxon_id,
      :tax_code_id,
      :default_variant_id
    ])
    |> cast_assoc(:images)
    |> cast_assoc(:variants)
    |> Slug.put_new_slug(unique_by: __MODULE__)
    |> validate_required([:name, :status, :product_type_id, :primary_taxon_id])
    |> assoc_constraint(:brand)
    |> assoc_constraint(:product_type)
    |> assoc_constraint(:primary_taxon)
    |> assoc_constraint(:tax_code)
    |> foreign_key_constraint(:default_variant_id, name: :products_default_variant_id_fkey)
  end
end
