defmodule Harbor.Catalog.ProductOptionValue do
  @moduledoc false
  use Harbor.Schema

  alias Harbor.Catalog.{OptionType, OptionValue, Product}

  @primary_key false
  schema "product_option_values" do
    belongs_to :product, Product, primary_key: true
    belongs_to :option_value, OptionValue, primary_key: true
    belongs_to :option_type, OptionType
  end

  @doc false
  def changeset(product_option_value, attrs) do
    product_option_value
    |> cast(attrs, [:product_id, :option_value_id, :option_type_id])
    |> validate_required([:product_id, :option_value_id, :option_type_id])
    |> assoc_constraint(:product)
    |> assoc_constraint(:option_value)
    |> assoc_constraint(:option_type)
    |> foreign_key_constraint(:option_type_id, name: :product_option_values_type_match)
    |> foreign_key_constraint(:option_value_id, name: :product_option_values_value_match)
  end
end
