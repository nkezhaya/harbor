defmodule Harbor.Catalog.Product do
  @moduledoc """
  A product is the shared catalog record that customers recognize.

  It holds the product's descriptive data, media, merchandising placement, its
  product-owned option structure, and the variants that can actually be
  purchased.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{
    Brand,
    ProductImage,
    ProductOption,
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
    field :taxon_ids, {:array, :binary_id}, virtual: true, default: []

    belongs_to :brand, Brand
    belongs_to :product_type, ProductType
    belongs_to :primary_taxon, Taxon
    belongs_to :tax_code, TaxCode
    belongs_to :master_variant, Variant, foreign_key: :master_variant_id

    has_many :images, ProductImage, preload_order: [:position], on_replace: :delete
    has_many :product_taxons, ProductTaxon, preload_order: [:position], on_replace: :delete
    has_many :taxons, through: [:product_taxons, :taxon]
    has_many :product_options, ProductOption, preload_order: [:position], on_replace: :delete
    has_many :product_property_values, ProductPropertyValue, on_replace: :delete
    has_many :variants, Variant, on_replace: :delete

    has_many :enabled_variants, Variant,
      where: [enabled: true],
      preload_order: [asc: :inserted_at]

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
      :taxon_ids,
      :tax_code_id
    ])
    |> cast_assoc(:images)
    |> cast_assoc(:product_options,
      sort_param: :product_options_sort,
      drop_param: :product_options_drop,
      with: &ProductOption.changeset/3
    )
    |> Slug.put_new_slug(unique_by: __MODULE__)
    |> validate_required([:name, :status, :product_type_id, :primary_taxon_id])
    |> validate_product_options_locked()
    |> assoc_constraint(:brand)
    |> assoc_constraint(:product_type)
    |> assoc_constraint(:primary_taxon)
    |> assoc_constraint(:tax_code)
    |> foreign_key_constraint(:primary_taxon_id,
      name: :products_primary_taxon_in_taxons,
      message: "must be one of the selected taxons"
    )
    |> check_constraint(:status,
      name: :active_products_must_have_purchasable_variant,
      message: "cannot be active without a purchasable variant"
    )
  end

  def with_master_variant_changeset(product, attrs) do
    product
    |> changeset(attrs)
    |> cast_assoc(:master_variant)
  end

  defp validate_product_options_locked(changeset) do
    master_variant_id = get_field(changeset, :master_variant_id)

    variants_locked? =
      Enum.any?(get_assoc(changeset, :variants), fn variant ->
        get_field(variant, :id) != master_variant_id
      end)

    if variants_locked? and changed?(changeset, :product_options) do
      add_error(changeset, :product_options, "cannot be changed once variants exist")
    else
      changeset
    end
  end

  def variant_changeset(product, attrs) do
    product
    |> cast(attrs, [])
    |> cast_assoc(:variants, sort_param: :variants_sort, drop_param: :variants_drop)
    |> check_constraint(:variants,
      name: :active_products_must_have_purchasable_variant,
      message: "must include a purchasable variant while the product is active"
    )
  end
end
