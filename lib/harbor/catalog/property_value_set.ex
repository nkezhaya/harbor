defmodule Harbor.Catalog.PropertyValueSet do
  @moduledoc """
  A property value set is a reusable pool of categorical values that one or more
  [Property](`Harbor.Catalog.Property`) records can share.

  For example, a furniture catalog might have an "Upholstery Material" value set
  with options like Leather, Linen, and Velvet that can be reused across sofas,
  dining chairs, and ottomans.
  """
  use Harbor.Schema

  alias Harbor.Catalog.{Property, PropertyOption}
  alias Harbor.Slug

  @type t() :: %__MODULE__{}

  schema "property_value_sets" do
    field :name, :string
    field :slug, :string

    has_many :properties, Property
    has_many :options, PropertyOption, preload_order: [:position], on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(property_value_set, attrs) do
    property_value_set
    |> cast(attrs, [:name, :slug])
    |> cast_assoc(:options,
      sort_param: :options_sort,
      drop_param: :options_drop,
      with: &PropertyOption.changeset/3
    )
    |> validate_required([:name])
    |> Slug.put_new_slug(unique_by: __MODULE__)
    |> unique_constraint(:name)
    |> unique_constraint(:slug)
  end
end
