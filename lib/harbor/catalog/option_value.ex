defmodule Harbor.Catalog.OptionValue do
  @moduledoc """
  Ecto schema for option values and their associations.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{OptionType, Variant, VariantOptionValue}
  alias Harbor.Slug

  @type t() :: %__MODULE__{}

  schema "option_values" do
    field :name, :string
    field :slug, :string
    field :position, :integer, default: 0
    field :delete, :boolean, default: false, virtual: true

    belongs_to :option_type, OptionType

    many_to_many :variants, Variant,
      join_through: VariantOptionValue,
      join_keys: [option_value_id: :id, variant_id: :id]

    timestamps()
  end

  @doc false
  def changeset(option_value, attrs) do
    option_value
    |> cast(attrs, [:name, :slug, :position, :delete])
    |> validate_required([:name, :position])
    |> Slug.put_new_slug()
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint([:option_type_id, :name])
    |> unique_constraint([:option_type_id, :slug])
  end

  def changeset(option_value, attrs, position) do
    option_value
    |> change(position: position)
    |> changeset(attrs)
  end
end
