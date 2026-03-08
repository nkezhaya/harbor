defmodule Harbor.Catalog.ProductPropertyValue do
  @moduledoc """
  This record stores the chosen value for a
  [Property](`Harbor.Catalog.Property`) directly on a
  [Product](`Harbor.Catalog.Product`).

  This is where product-level facts like material, fit, or country of origin
  live.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{Product, Property, PropertyOption}

  @type t() :: %__MODULE__{}

  schema "product_property_values" do
    field :string_value, :string
    field :text_value, :string
    field :integer_value, :integer
    field :decimal_value, :decimal
    field :boolean_value, :boolean
    field :date_value, :date

    belongs_to :product, Product
    belongs_to :property, Property
    belongs_to :property_option, PropertyOption

    timestamps()
  end

  @doc false
  def changeset(product_property_value, attrs) do
    product_property_value
    |> cast(attrs, [
      :product_id,
      :property_id,
      :property_option_id,
      :string_value,
      :text_value,
      :integer_value,
      :decimal_value,
      :boolean_value,
      :date_value
    ])
    |> validate_required([:product_id, :property_id])
    |> assoc_constraint(:product)
    |> assoc_constraint(:property)
    |> assoc_constraint(:property_option)
    |> unique_constraint([:product_id, :property_id],
      name: :product_property_values_single_unique
    )
    |> unique_constraint([:product_id, :property_id, :property_option_id],
      name: :product_property_values_multi_unique
    )
  end
end
