defmodule Harbor.Catalog.Product do
  @moduledoc """
  Ecto schema for products and their associations.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{Category, OptionType, ProductImage, Variant}
  alias Harbor.Slug
  alias Harbor.Tax.TaxCode

  @type t() :: %__MODULE__{}

  schema "products" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :status, Ecto.Enum, values: [:draft, :active, :archived], default: :draft
    field :physical_product, :boolean, default: true

    belongs_to :tax_code, TaxCode
    belongs_to :category, Category
    belongs_to :default_variant, Variant

    has_many :images, ProductImage, preload_order: [:position], on_replace: :delete
    has_many :option_types, OptionType, preload_order: [:position], on_replace: :delete
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
      :tax_code_id,
      :category_id,
      :default_variant_id
    ])
    |> cast_assoc(:images)
    |> cast_assoc(:option_types,
      sort_param: :option_types_sort,
      drop_param: :option_types_drop,
      with: &OptionType.changeset/3
    )
    |> cast_assoc(:variants)
    |> Slug.put_new_slug(__MODULE__)
    |> validate_required([:name, :status, :category_id])
    |> assoc_constraint(:tax_code)
    |> assoc_constraint(:category)
    |> foreign_key_constraint(:default_variant_id)
  end
end
