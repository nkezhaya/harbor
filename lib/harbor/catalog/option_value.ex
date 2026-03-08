defmodule Harbor.Catalog.OptionValue do
  @moduledoc """
  An option value is one concrete choice inside an
  [OptionType](`Harbor.Catalog.OptionType`), such as Medium or Black.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{OptionType, ProductOptionValue, VariantOptionValue}
  alias Harbor.Slug

  @type t() :: %__MODULE__{}

  schema "option_values" do
    field :name, :string
    field :slug, :string
    field :position, :integer, default: 0
    field :delete, :boolean, default: false, virtual: true

    belongs_to :option_type, OptionType

    has_many :product_option_values, ProductOptionValue
    has_many :variant_option_values, VariantOptionValue
    has_many :variants, through: [:variant_option_values, :variant]

    timestamps()
  end

  @doc false
  def changeset(option_value, attrs) do
    option_value
    |> cast(attrs, [:option_type_id, :name, :slug, :position, :delete])
    |> validate_required([:name, :position])
    |> Slug.put_new_slug()
    |> assoc_constraint(:option_type)
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint([:option_type_id, :name])
    |> unique_constraint([:option_type_id, :slug])
    |> put_delete_if_set()
  end

  def changeset(option_value, attrs, position) do
    option_value
    |> change(position: position)
    |> changeset(attrs)
  end
end
