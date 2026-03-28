defmodule Harbor.Catalog.Variant do
  @moduledoc """
  A variant is a concrete purchasable row for a
  [Product](`Harbor.Catalog.Product`).

  It is the record that carries the SKU, price, inventory state, and the
  specific product option values the customer is buying.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{Product, VariantOptionValue, VariantPropertyValue}
  alias Harbor.Tax.TaxCode

  @type t() :: %__MODULE__{}

  schema "variants" do
    field :sku, :string
    field :price, Money.Ecto.Composite.Type
    field :quantity_available, :integer, default: 0
    field :enabled, :boolean, default: false

    field :inventory_policy, Ecto.Enum,
      values: [:not_tracked, :track_strict, :track_allow],
      default: :not_tracked

    belongs_to :product, Product
    belongs_to :tax_code, TaxCode

    has_many :variant_option_values, VariantOptionValue, on_replace: :delete
    has_many :option_values, through: [:variant_option_values, :product_option_value]
    has_many :variant_property_values, VariantPropertyValue, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(variant, attrs) do
    variant
    |> cast(attrs, [
      :sku,
      :price,
      :quantity_available,
      :enabled,
      :inventory_policy,
      :tax_code_id
    ])
    |> cast_assoc(:variant_option_values, with: &VariantOptionValue.changeset/2)
    |> validate_required([
      :price,
      :quantity_available,
      :enabled,
      :inventory_policy
    ])
    |> assoc_constraint(:product)
    |> assoc_constraint(:tax_code)
    |> check_constraint(:price,
      name: :price_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> check_constraint(:quantity_available,
      name: :quantity_available_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint(:sku)
  end

  @doc """
  Returns the first [ProductImage](`Harbor.Catalog.ProductImage`) associated
  with the variant's [Product](`Harbor.Catalog.Product`).
  """
  def main_image(%__MODULE__{product: %{images: [image | _]}}), do: image
  def main_image(_variant), do: nil

  @doc """
  Returns a user-friendly description for a variant built from its associated
  [ProductOptionValue](`Harbor.Catalog.ProductOptionValue`) records.
  """
  def description(%__MODULE__{option_values: option_values, sku: sku})
      when is_list(option_values) do
    case Enum.map_join(option_values, ", ", & &1.name) do
      "" -> sku
      desc -> desc
    end
  end

  def description(_variant), do: nil
end
