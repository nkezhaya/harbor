defmodule Harbor.Catalog.ProductTypeProperty do
  @moduledoc false
  use Harbor.Schema

  alias Harbor.Catalog.{ProductType, Property}

  @primary_key false
  schema "product_type_properties" do
    belongs_to :product_type, ProductType, primary_key: true
    belongs_to :property, Property, primary_key: true
    field :required, :boolean, default: false
    field :position, :integer, default: 0
  end

  @doc false
  def changeset(product_type_property, attrs) do
    product_type_property
    |> cast(attrs, [:product_type_id, :property_id, :required, :position])
    |> validate_required([:product_type_id, :property_id, :required, :position])
    |> assoc_constraint(:product_type)
    |> assoc_constraint(:property)
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
  end
end
