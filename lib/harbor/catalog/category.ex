defmodule Harbor.Catalog.Category do
  @moduledoc """
  Ecto schema for product categories and hierarchy.
  """
  use Harbor.Schema
  alias Harbor.Catalog.Product
  alias Harbor.Tax.TaxCode

  @type t() :: %__MODULE__{}

  schema "categories" do
    field :name, :string
    field :slug, :string
    field :position, :integer
    field :parent_ids, {:array, :binary_id}

    belongs_to :parent, __MODULE__
    belongs_to :tax_code, TaxCode
    has_many :children, __MODULE__, foreign_key: :parent_id
    many_to_many :products, Product, join_through: "products_categories"

    timestamps()
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :slug, :position, :parent_ids, :tax_code_id])
    |> validate_required([:name, :slug, :position])
    |> unique_constraint(:slug)
    |> assoc_constraint(:tax_code)
  end
end
