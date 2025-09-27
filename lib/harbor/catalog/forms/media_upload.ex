defmodule Harbor.Catalog.Forms.MediaUpload do
  @moduledoc """
  Embedded struct for the [ProductForm](`Harbor.Catalog.Forms.ProductForm`) that
  stores temporary file uploads before the [Product](`Harbor.Catalog.Product`)
  is persisted. On save, this gets promoted to a
  [ProductImage](`Harbor.Catalog.ProductImage`).
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: false}
  embedded_schema do
    field :product_image_id, :binary_id
    field :file_name, :string
    field :file_type, :string
    field :key, :string
  end

  @doc false
  def changeset(media_upload, attrs) do
    media_upload
    |> cast(attrs, [:product_image_id, :file_name, :file_type, :key])
    |> put_new_key()
  end

  defp put_new_key(changeset) do
    with nil <- get_field(changeset, :id),
         nil <- get_field(changeset, :key) do
      id = Ecto.UUID.generate()
      ext = Path.extname(get_field(changeset, :file_name))
      key = "media_uploads/#{id}/original#{ext}"

      change(changeset, %{id: id, key: key})
    else
      _ -> changeset
    end
  end
end
