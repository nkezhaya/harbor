defmodule Harbor.Catalog.VariantOptionValue do
  @moduledoc false
  use Harbor.Schema

  alias Harbor.Catalog.{OptionType, OptionValue, Variant}

  @primary_key false
  schema "variants_option_values" do
    belongs_to :variant, Variant, primary_key: true
    belongs_to :option_value, OptionValue, primary_key: true
    belongs_to :option_type, OptionType
  end

  @doc false
  def changeset(variant_option_value, attrs) do
    variant_option_value
    |> cast(attrs, [:variant_id, :option_value_id, :option_type_id])
    |> validate_required([:variant_id, :option_value_id, :option_type_id])
    |> assoc_constraint(:variant)
    |> assoc_constraint(:option_value)
    |> assoc_constraint(:option_type)
    |> foreign_key_constraint(:option_value_id, name: :variants_option_values_type_match)
    |> unique_constraint([:variant_id, :option_type_id],
      name: :variants_option_values_one_per_type
    )
  end
end
