defmodule Harbor.Catalog.VariantPropertyValue do
  @moduledoc """
  This record stores the chosen value for a
  [Property](`Harbor.Catalog.Property`) directly on a
  [Variant](`Harbor.Catalog.Variant`).

  Use it for facts that vary between purchasable rows.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{Property, PropertyOption, Variant}

  @type t() :: %__MODULE__{}

  schema "variant_property_values" do
    field :string_value, :string
    field :text_value, :string
    field :integer_value, :integer
    field :decimal_value, :decimal
    field :boolean_value, :boolean
    field :date_value, :date

    belongs_to :variant, Variant
    belongs_to :property, Property
    belongs_to :property_option, PropertyOption

    timestamps()
  end

  @doc false
  def changeset(variant_property_value, attrs) do
    variant_property_value
    |> cast(attrs, [
      :variant_id,
      :property_id,
      :property_option_id,
      :string_value,
      :text_value,
      :integer_value,
      :decimal_value,
      :boolean_value,
      :date_value
    ])
    |> validate_required([:variant_id, :property_id])
    |> assoc_constraint(:variant)
    |> assoc_constraint(:property)
    |> assoc_constraint(:property_option)
    |> unique_constraint([:variant_id, :property_id],
      name: :variant_property_values_single_unique
    )
    |> unique_constraint([:variant_id, :property_id, :property_option_id],
      name: :variant_property_values_multi_unique
    )
  end
end
