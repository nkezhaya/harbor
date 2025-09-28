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
    field :file_size, :integer
    field :file_type, :string
    field :key, :string
    field :status, Ecto.Enum, values: [:pending, :complete], default: :pending
  end

  @doc false
  def changeset(media_upload, attrs) do
    media_upload
    |> cast(attrs, [:id, :product_image_id, :file_name, :file_size, :file_type, :key])
    |> validate_required([:id, :file_type])
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
