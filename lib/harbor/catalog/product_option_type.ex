defmodule Harbor.Catalog.ProductOptionType do
  @moduledoc false
  use Harbor.Schema

  alias Harbor.Catalog.{OptionType, Product, ProductType}

  @primary_key false
  schema "product_option_types" do
    belongs_to :product, Product, primary_key: true
    belongs_to :option_type, OptionType, primary_key: true
    belongs_to :product_type, ProductType
    field :position, :integer, default: 0
  end

  @doc false
  def changeset(product_option_type, attrs) do
    product_option_type
    |> cast(attrs, [:product_id, :option_type_id, :product_type_id, :position])
    |> validate_required([:product_id, :option_type_id, :product_type_id, :position])
    |> assoc_constraint(:product)
    |> assoc_constraint(:option_type)
    |> assoc_constraint(:product_type)
    |> foreign_key_constraint(:product_type_id, name: :product_option_types_product_type_match)
    |> foreign_key_constraint(:option_type_id, name: :product_option_types_allowed_by_type)
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
  end
end
