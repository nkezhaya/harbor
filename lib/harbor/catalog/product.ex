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
    field :status, Ecto.Enum, values: [:draft, :active, :archived]

    belongs_to :tax_code, TaxCode
    belongs_to :default_variant, Variant

    has_many :product_images, ProductImage, on_replace: :delete
    has_many :option_types, OptionType, on_replace: :delete
    has_many :variants, Variant, on_replace: :delete

    many_to_many :categories, Category,
      join_through: "products_categories",
      join_keys: [product_id: :id, category_id: :id]

    timestamps()
  end

  @doc false
  def changeset(product, attrs) do
    product
    |> cast(attrs, [:name, :slug, :description, :status, :tax_code_id, :default_variant_id])
    |> cast_assoc(:option_types)
    |> cast_assoc(:variants)
    |> cast_assoc(:product_images)
    |> Slug.put_new_slug(__MODULE__)
    |> validate_required([:name, :status, :tax_code_id])
    |> assoc_constraint(:tax_code)
    |> assoc_constraint(:default_variant)
  end
end
