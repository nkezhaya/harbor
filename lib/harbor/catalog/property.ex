defmodule Harbor.Catalog.Property do
  @moduledoc """
  A property describes a fact about a product or variant that should be stored
  as structured catalog data.

  The important idea is that a property does not automatically create a new SKU.
  It answers questions like:

  - What is this made from?
  - What kind of fit does it have?
  - Does this variant have a different shipping weight?
  - Which categorical values can be used for this fact?

  For example:

  - A sofa might have a product-level property called "Upholstery Material"
    with the value "Velvet".
  - A dining table might have a product-level property called "Shape" with the
    value "Round".
  - A suitcase might have a variant-level property called "Packed Weight" if
    different sizes have different shipping weights.

  Properties are different from [ProductOption](`Harbor.Catalog.ProductOption`)
  records.

  Use a product option when the choice defines a purchasable combination, such
  as Size or Color.

  Use a property when the value is descriptive data, such as Material, Care
  Instructions, or Country of Origin.

  The main fields are:

  - `name`: The human-readable label, such as "Material" or "Packed Weight".
  - `slug`: The path used in URLs, filters, and internal lookups.
  - `value_type`: The kind of value this property stores (e.g., `:string`).
  - `unit`: An optional unit for numeric values, such as "lb", "kg", "cm", or
    "in".
  - `applies_to`: Whether the property belongs on the whole
    [Product](`Harbor.Catalog.Product`) or on each
    [Variant](`Harbor.Catalog.Variant`).
  - `filterable`: Whether this property should be available for storefront or
    admin filtering.
  - `multi_value`: Whether more than one value can be attached at the same
    time.
  - `position`: A display-order field used when listing properties in the UI.
  - `property_group_id`: The group this property belongs to for authoring and
    presentation.
  - `property_value_set_id`: An optional shared set of categorical values that
    this property draws from.

  A few examples of how these fields fit together:

  - "Material" might use `value_type: :string`, `applies_to: :product`,
    `filterable: true`, and a shared
    [PropertyValueSet](`Harbor.Catalog.PropertyValueSet`) containing values
    like Leather, Linen, and Velvet.
  - "Packed Weight" might use `value_type: :decimal`, `unit: "lb"`, and
    `applies_to: :variant`.
  - "Assembly Required" might use `value_type: :boolean` and
    `applies_to: :product`.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{
    ProductPropertyValue,
    ProductTypeProperty,
    PropertyGroup,
    PropertyValueSet,
    VariantPropertyValue
  }

  alias Harbor.Slug

  @value_types [:string, :text, :integer, :decimal, :boolean, :date]
  @applies_to_values [:product, :variant]

  @type t() :: %__MODULE__{}

  schema "properties" do
    field :name, :string
    field :slug, :string
    field :value_type, Ecto.Enum, values: @value_types
    field :unit, :string
    field :applies_to, Ecto.Enum, values: @applies_to_values
    field :filterable, :boolean, default: false
    field :multi_value, :boolean, default: false
    field :position, :integer, default: 0

    belongs_to :property_group, PropertyGroup
    belongs_to :property_value_set, PropertyValueSet

    has_many :product_type_properties, ProductTypeProperty, on_replace: :delete
    has_many :product_types, through: [:product_type_properties, :product_type]
    has_many :product_property_values, ProductPropertyValue
    has_many :variant_property_values, VariantPropertyValue

    timestamps()
  end

  @doc false
  def changeset(property, attrs) do
    property
    |> cast(attrs, [
      :property_group_id,
      :property_value_set_id,
      :name,
      :slug,
      :value_type,
      :unit,
      :applies_to,
      :filterable,
      :multi_value,
      :position
    ])
    |> validate_required([:property_group_id, :name, :value_type, :applies_to, :position])
    |> Slug.put_new_slug(unique_by: __MODULE__)
    |> assoc_constraint(:property_group)
    |> assoc_constraint(:property_value_set)
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint(:slug)
  end
end
