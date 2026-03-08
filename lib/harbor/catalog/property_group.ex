defmodule Harbor.Catalog.PropertyGroup do
  @moduledoc """
  A property group organizes related [Property](`Harbor.Catalog.Property`)
  records so they can be presented together in admin screens and product detail
  pages.

  For example, a furniture product might have a group called "Dimensions" that
  contains Width, Depth, and Height, or a group called "Materials" that contains
  Upholstery Material and Frame Material.

  A property group is for organization and presentation. It does not control
  validation rules, filtering behavior, or whether a property applies to a
  product or a variant.
  """
  use Harbor.Schema

  alias Harbor.Catalog.Property
  alias Harbor.Slug

  @type t() :: %__MODULE__{}

  schema "property_groups" do
    field :name, :string
    field :slug, :string
    field :position, :integer, default: 0

    has_many :properties, Property, preload_order: [:position]

    timestamps()
  end

  @doc false
  def changeset(property_group, attrs) do
    property_group
    |> cast(attrs, [:name, :slug, :position])
    |> validate_required([:name, :position])
    |> Slug.put_new_slug(unique_by: __MODULE__)
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint(:slug)
  end
end
