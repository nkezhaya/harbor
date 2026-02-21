defmodule Harbor.Catalog.OptionType do
  @moduledoc """
  Ecto schema for product option types (e.g., size, color).
  """
  use Harbor.Schema

  alias Harbor.Catalog.{OptionValue, Product}
  alias Harbor.Slug

  @type t() :: %__MODULE__{}

  schema "option_types" do
    field :name, :string
    field :slug, :string
    field :position, :integer, default: 0
    field :delete, :boolean, default: false, virtual: true

    belongs_to :product, Product
    has_many :values, OptionValue, preload_order: [:position], on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(option_type, attrs) do
    option_type
    |> cast(attrs, [:name, :slug, :position])
    |> cast_assoc(:values,
      sort_param: :values_sort,
      drop_param: :values_drop,
      with: &OptionValue.changeset/3
    )
    |> validate_required([:name, :position])
    |> Slug.put_new_slug()
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint([:product_id, :name])
    |> unique_constraint([:product_id, :slug])
  end

  def changeset(option_type, attrs, position) do
    option_type
    |> change(position: position)
    |> changeset(attrs)
  end
end
