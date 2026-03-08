defmodule Harbor.Catalog.OptionType do
  @moduledoc """
  An option type is a reusable variant dimension, such as Size or Color.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{OptionValue, ProductOptionType, ProductTypeOptionType}
  alias Harbor.Slug

  @type t() :: %__MODULE__{}

  schema "option_types" do
    field :name, :string
    field :slug, :string
    field :position, :integer, default: 0
    field :delete, :boolean, default: false, virtual: true

    has_many :values, OptionValue, preload_order: [:position], on_replace: :delete
    has_many :product_type_option_types, ProductTypeOptionType
    has_many :product_option_types, ProductOptionType

    timestamps()
  end

  @doc false
  def changeset(option_type, attrs) do
    option_type
    |> cast(attrs, [:name, :slug, :position, :delete])
    |> cast_assoc(:values,
      sort_param: :values_sort,
      drop_param: :values_drop,
      with: &OptionValue.changeset/3
    )
    |> validate_required([:name, :position])
    |> Slug.put_new_slug(unique_by: __MODULE__)
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint(:name)
    |> unique_constraint(:slug)
    |> put_delete_if_set()
  end

  def changeset(option_type, attrs, position) do
    option_type
    |> change(position: position)
    |> changeset(attrs)
  end
end
