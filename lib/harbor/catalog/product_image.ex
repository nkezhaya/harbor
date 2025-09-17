defmodule Harbor.Catalog.ProductImage do
  @moduledoc """
  Ecto schema for product images with attachment handling.
  """
  use Harbor.Schema
  use Waffle.Ecto.Schema

  alias Harbor.Catalog.Product

  @type t() :: %__MODULE__{}

  schema "product_images" do
    field :image, :string
    field :position, :integer, default: 0

    belongs_to :product, Product

    timestamps()
  end

  @doc false
  def changeset(image, attrs) do
    image
    |> cast(attrs, [:image, :position])
    |> cast_attachments(attrs, [:image])
    |> validate_required([:image])
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint([:product_id, :position])
  end
end
