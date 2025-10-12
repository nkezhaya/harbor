defmodule Harbor.Catalog.Forms.MediaUpload do
  @moduledoc """
  Embedded struct for the product form that stores temporary file uploads before
  the [Product](`Harbor.Catalog.Product`) is persisted. On save, this gets
  promoted to a [ProductImage](`Harbor.Catalog.ProductImage`).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Harbor.Catalog.ProductImage

  @primary_key {:id, :binary_id, autogenerate: false}
  embedded_schema do
    field :product_image_id, :binary_id
    field :file_name, :string
    field :file_size, :integer
    field :file_type, :string
    field :alt_text, :string
    field :key, :string
    field :position, :integer, default: 0
    field :status, Ecto.Enum, values: [:pending, :complete], default: :pending
    field :delete, :boolean, default: false
  end

  def from_product_image(%ProductImage{} = image) do
    %__MODULE__{
      id: image.id,
      product_image_id: image.id,
      file_name: image.file_name,
      file_size: image.file_size,
      file_type: image.file_type,
      key: image.image_path,
      position: image.position,
      status: :complete
    }
  end

  @doc false
  def changeset(media_upload, attrs) do
    media_upload
    |> cast(attrs, [
      :id,
      :product_image_id,
      :file_name,
      :file_size,
      :file_type,
      :alt_text,
      :key,
      :position,
      :delete
    ])
    |> validate_required([:id, :file_name, :file_size, :file_type])
    |> put_new_key()
  end

  defp put_new_key(%{valid?: true} = changeset) do
    case get_field(changeset, :key) do
      nil ->
        id = get_field(changeset, :id)
        ext = Path.extname(get_field(changeset, :file_name))
        key = "media_uploads/#{id}/original#{ext}"

        change(changeset, %{id: id, key: key})

      _ ->
        changeset
    end
  end

  defp put_new_key(changeset) do
    changeset
  end
end
