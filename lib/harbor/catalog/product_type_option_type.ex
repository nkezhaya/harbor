defmodule Harbor.Catalog.ProductTypeOptionType do
  @moduledoc false
  use Harbor.Schema

  alias Harbor.Catalog.{OptionType, ProductType}

  @primary_key false
  schema "product_type_option_types" do
    belongs_to :product_type, ProductType, primary_key: true
    belongs_to :option_type, OptionType, primary_key: true
    field :position, :integer, default: 0
  end

  @doc false
  def changeset(product_type_option_type, attrs) do
    product_type_option_type
    |> cast(attrs, [:product_type_id, :option_type_id, :position])
    |> validate_required([:product_type_id, :option_type_id, :position])
    |> assoc_constraint(:product_type)
    |> assoc_constraint(:option_type)
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
  end
end
