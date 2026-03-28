defmodule Harbor.Catalog.ProductOptionValue do
  @moduledoc """
  A product option value is one concrete choice inside a product-owned option,
  such as Small or Black.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{ProductOption, VariantOptionValue}

  @type t() :: %__MODULE__{}

  schema "product_option_values" do
    field :name, :string
    field :position, :integer, default: 0

    belongs_to :product_option, ProductOption

    has_many :variant_option_values, VariantOptionValue
    has_many :variants, through: [:variant_option_values, :variant]

    timestamps()
  end

  @doc false
  def changeset(product_option_value, attrs) do
    product_option_value
    |> cast(attrs, [:name])
    |> validate_required([:name, :position])
    |> assoc_constraint(:product_option)
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint(:name, name: :product_option_values_product_option_id_name_index)
  end

  def changeset(product_option_value, attrs, position) do
    product_option_value
    |> change(position: position)
    |> changeset(attrs)
  end
end
