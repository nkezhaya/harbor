defmodule Harbor.Catalog.Variant do
  @moduledoc """
  Ecto schema for product variants with pricing and inventory.
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
    field :track_inventory, :boolean, default: true

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
      :track_inventory,
      :tax_code_id
    ])
    |> validate_required([
      :sku,
      :price,
      :quantity_available,
      :enabled,
      :track_inventory
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
end
