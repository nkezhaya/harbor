defmodule Harbor.Catalog.ProductImage do
  @moduledoc """
  Ecto schema for product images with attachment handling.
  """
  use Harbor.Schema

  alias Harbor.Catalog.Product

  @type t() :: %__MODULE__{}

  schema "product_images" do
    field :status, Ecto.Enum, values: [:pending, :ready], default: :pending
    field :file_name, :string
    field :file_size, :integer
    field :file_type, :string
    field :alt_text, :string
    field :image_path, :string
    field :temp_upload_path, :string
    field :position, :integer, default: 0

    belongs_to :product, Product

    timestamps()
  end

  @doc false
  def changeset(image, attrs) do
    image
    |> cast(attrs, [
      :product_id,
      :status,
      :file_name,
      :file_size,
      :file_type,
      :alt_text,
      :image_path,
      :temp_upload_path,
      :position
    ])
    |> validate_required([:product_id, :file_name, :file_size, :file_type, :image_path])
    |> check_constraint(:temp_upload_path,
      name: :check_temp_upload_path,
      message: "is required for pending images"
    )
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint([:product_id, :position],
      error_key: :position,
      name: :product_images_product_id_position_unique
    )
  end
end
