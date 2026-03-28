defmodule Harbor.Catalog.VariantOptionValue do
  @moduledoc false
  use Harbor.Schema

  alias Harbor.Catalog.{ProductOption, ProductOptionValue, Variant}

  @type t() :: %__MODULE__{}

  schema "variants_option_values" do
    belongs_to :variant, Variant
    belongs_to :product_option, ProductOption
    belongs_to :product_option_value, ProductOptionValue
  end

  @doc false
  def changeset(variant_option_value, attrs) do
    variant_option_value
    |> cast(attrs, [:product_option_id, :product_option_value_id])
    |> validate_required([:product_option_id, :product_option_value_id])
    |> assoc_constraint(:variant)
    |> foreign_key_constraint(:product_option_id,
      name: :variants_option_values_product_option_fkey
    )
    |> foreign_key_constraint(:product_option_value_id,
      name: :variants_option_values_option_match
    )
    |> unique_constraint([:variant_id, :product_option_id],
      name: :variants_option_values_one_per_option
    )
  end
end
