defmodule Harbor.Catalog.Brand do
  @moduledoc """
  A brand is the maker or label attached to products, such as Nike or Uniqlo.
  """
  use Harbor.Schema

  alias Harbor.Catalog.Product
  alias Harbor.Slug

  @type t() :: %__MODULE__{}

  schema "brands" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :logo_path, :string
    field :position, :integer, default: 0

    has_many :products, Product

    timestamps()
  end

  @doc false
  def changeset(brand, attrs) do
    brand
    |> cast(attrs, [:name, :slug, :description, :logo_path, :position])
    |> validate_required([:name, :position])
    |> Slug.put_new_slug(unique_by: __MODULE__)
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint(:name)
    |> unique_constraint(:slug)
  end
end
