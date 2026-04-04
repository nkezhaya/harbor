defmodule Harbor.Catalog.ProductOption do
  @moduledoc """
  A product option is one sellable variation dimension owned by a product,
  such as Size or Color.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{Product, ProductOptionValue, VariantOptionValue}

  @type t() :: %__MODULE__{}

  schema "product_options" do
    field :name, :string
    field :position, :integer, default: 0

    belongs_to :product, Product
    has_many :values, ProductOptionValue, preload_order: [:position], on_replace: :delete
    has_many :variant_option_values, VariantOptionValue

    timestamps()
  end

  @doc false
  def changeset(product_option, attrs) do
    product_option
    |> cast(attrs, [:name])
    |> cast_assoc(:values,
      sort_param: :values_sort,
      drop_param: :values_drop,
      with: &ProductOptionValue.changeset/3
    )
    |> validate_required([:name, :position])
    |> assoc_constraint(:product)
    |> check_constraint(:values,
      name: :product_options_must_have_values,
      message: "must be present."
    )
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint(:name, name: :product_options_product_id_name_index)
  end

  def changeset(product_option, attrs, position) do
    product_option
    |> change(position: position)
    |> changeset(attrs)
  end
end
