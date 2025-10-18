defmodule Harbor.Catalog.Category do
  @moduledoc """
  Ecto schema for product categories and hierarchy.
  """
  use Harbor.Schema

  alias Harbor.Catalog.Product
  alias Harbor.Slug
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
    has_many :products, Product

    timestamps()
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name, :slug, :position, :parent_ids, :tax_code_id])
    |> Slug.put_new_slug(__MODULE__)
    |> validate_required([:name, :tax_code_id])
    |> assoc_constraint(:tax_code)
    |> put_new_position()
  end

  defp put_new_position(changeset) do
    case get_field(changeset, :position) do
      nil -> prepare_changes(changeset, &put_default_position/1)
      _ -> changeset
    end
  end

  defp put_default_position(prepared_changeset) do
    count =
      case get_field(prepared_changeset, :parent_id) do
        nil ->
          from(c in __MODULE__, where: is_nil(c.parent_id))

        parent_id ->
          from(c in __MODULE__, where: c.parent_id == ^parent_id)
      end
      |> prepared_changeset.repo.aggregate(:count, :id)

    put_change(prepared_changeset, :position, count)
  end
end
