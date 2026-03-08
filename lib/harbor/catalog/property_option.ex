defmodule Harbor.Catalog.PropertyOption do
  @moduledoc """
  A property option is a named choice inside a shared
  [PropertyValueSet](`Harbor.Catalog.PropertyValueSet`), such as Cotton or Wool.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{ProductPropertyValue, PropertyValueSet, VariantPropertyValue}
  alias Harbor.Slug

  @type t() :: %__MODULE__{}

  schema "property_options" do
    field :name, :string
    field :slug, :string
    field :position, :integer, default: 0
    field :delete, :boolean, default: false, virtual: true

    belongs_to :property_value_set, PropertyValueSet

    has_many :product_property_values, ProductPropertyValue
    has_many :variant_property_values, VariantPropertyValue

    timestamps()
  end

  @doc false
  def changeset(property_option, attrs) do
    property_option
    |> cast(attrs, [:property_value_set_id, :name, :slug, :position, :delete])
    |> validate_required([:name, :position])
    |> Slug.put_new_slug()
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint([:property_value_set_id, :name])
    |> unique_constraint([:property_value_set_id, :slug])
    |> put_delete_if_set()
  end

  def changeset(property_option, attrs, position) do
    property_option
    |> change(position: position)
    |> changeset(attrs)
  end
end
