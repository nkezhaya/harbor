defmodule Harbor.Catalog.Variant do
  @moduledoc """
  Schema and helpers for product variants within the catalog.

  A variant represents a purchasable permutation of a product with its own SKU,
  pricing, tax code and inventory tracking state. The helper functions in this
  module provide convenient access to display data already loaded via
  associations.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{OptionValue, Product}
  alias Harbor.Tax.TaxCode

  @type t() :: %__MODULE__{}

  schema "variants" do
    field :sku, :string
    field :price, :integer
    field :quantity_available, :integer, default: 0
    field :enabled, :boolean, default: false

    field :inventory_policy, Ecto.Enum,
      values: [:not_tracked, :track_strict, :track_allow],
      default: :not_tracked

    belongs_to :product, Product
    belongs_to :tax_code, TaxCode

    many_to_many :option_values, OptionValue,
      join_through: "variants_option_values",
      join_keys: [variant_id: :id, option_value_id: :id]

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
    |> validate_required([
      :price,
      :quantity_available,
      :enabled,
      :inventory_policy
    ])
    |> check_constraint(:price,
      name: :price_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> check_constraint(:quantity_available,
      name: :quantity_available_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint(:sku)
    |> assoc_constraint(:tax_code)
  end

  @doc """
  Returns the first [ProductImage](`Harbor.Catalog.ProductImage`) associated
  with the variant's [Product](`Harbor.Catalog.Product`).

  The variant is expected to have its product association preloaded alongside
  the `images` collection. When no image is available, or the association is not
  loaded, `nil` is returned.
  """
  def main_image(%__MODULE__{product: %{images: [image | _]}}), do: image
  def main_image(_variant), do: nil

  @doc """
  Returns a user-friendly description for a variant built from its associated
  [OptionValue](`Harbor.Catalog.OptionValue`) records.

  When the `option_values` association is preloaded, the option names are joined
  with a comma. If no option values are present, the variant's SKU is returned.
  Returns `nil` when the association is unavailable so callers can decide how to
  handle missing data.
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
