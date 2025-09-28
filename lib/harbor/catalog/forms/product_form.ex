defmodule Harbor.Catalog.Forms.ProductForm do
  @moduledoc """
  Embedded schema representing the data captured in the admin product form.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Ecto.Changeset
  alias Harbor.Catalog.Forms.{MediaUpload, MediaUploadPromotionWorker}
  alias Harbor.Catalog.{Product, ProductImage}
  alias Harbor.Repo

  @type t() :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    embeds_one :product, Product, on_replace: :update
    embeds_many :media_uploads, MediaUpload
  end

  @doc """
  Returns a product form with the data associated with the given product.
  """
  @spec new() :: t()
  def new do
    %__MODULE__{}
  end

  @spec new(Product.t()) :: t()
  def new(%Product{} = product) do
    %__MODULE__{product: product}
  end

  @doc """
  Builds a changeset for the product form.
  """
  @spec changeset(t(), map()) :: Changeset.t()
  def changeset(product_form, attrs \\ %{}) do
    product_form
    |> cast(attrs, [])
    |> cast_embed(:product, required: true)
    |> cast_embed(:media_uploads)
  end

  def insert_new_media_upload(product_form, attrs) do
    result =
      %MediaUpload{}
      |> MediaUpload.changeset(attrs)
      |> Changeset.apply_action(:insert)

    with {:ok, media_upload} <- result do
      media_uploads = product_form.media_uploads ++ [media_upload]

      {:ok, %{product_form | media_uploads: media_uploads}, media_upload}
    end
  end

  @doc """
  Saves the product data and all associations.
  """
  @spec create_product(t(), map()) :: {:ok, Product.t()} | {:error, Changeset.t()}
  def create_product(%__MODULE__{} = product_form, params) do
    persist_product(product_form, params, :insert)
  end

  @spec update_product(t(), map()) :: {:ok, Product.t()} | {:error, Changeset.t()}
  def update_product(%__MODULE__{} = product_form, params) do
    persist_product(product_form, params, :update)
  end

  defp persist_product(product_form, params, action) do
    form_changeset = changeset(product_form, params)

    with {:ok, product_form} <- apply_action(form_changeset, action) do
      Repo.transact(fn ->
        product_changeset = get_embed(form_changeset, :product)

        with {:ok, product} <- Repo.insert_or_update(product_changeset),
             {:ok, product_images} <- promote_media_uploads(product, product_form.media_uploads) do
          {:ok, %{product | images: product_images}}
        end
      end)
    end
  end

  defp promote_media_uploads(%Product{} = product, media_uploads) do
    product = Repo.preload(product, :images)

    media_uploads
    |> Enum.with_index(length(product.images))
    |> Enum.reduce_while({:ok, []}, fn {media_upload, position}, {:ok, acc} ->
      attrs = %{
        product_id: product.id,
        temp_upload_path: media_upload.key,
        image_path: image_path(product, media_upload),
        position: position
      }

      with {:ok, product_image} <- insert_product_image(attrs),
           {:ok, _} <- insert_promotion_job(product_image) do
        {:cont, {:ok, [product_image | acc]}}
      else
        {:error, changeset} -> {:halt, {:error, changeset}}
      end
    end)
    |> case do
      {:ok, product_images} -> {:ok, Enum.reverse(product_images)}
      error -> error
    end
  end

  defp insert_product_image(attrs) do
    %ProductImage{}
    |> ProductImage.changeset(attrs)
    |> Repo.insert()
  end

  defp insert_promotion_job(product_image) do
    %{product_image_id: product_image.id}
    |> MediaUploadPromotionWorker.new()
    |> Oban.insert()
  end

  defp image_path(%Product{} = product, %MediaUpload{} = media_upload) do
    [_ | tail] = Path.split(media_upload.key)
    Path.join(["products", product.id, "images"] ++ tail)
  end
end
