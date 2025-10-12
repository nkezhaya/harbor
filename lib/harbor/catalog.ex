defmodule Harbor.Catalog do
  @moduledoc """
  The Catalog context.
  """
  import Ecto.Query, warn: false

  alias Harbor.Repo
  alias Harbor.Catalog.{Category, Product, ProductImage}
  alias Harbor.Catalog.Forms.{MediaUpload, MediaUploadPromotionWorker}

  ## Products

  def list_products do
    Product
    |> preload([:variants])
    |> Repo.all()
  end

  def list_storefront_products do
    Product
    |> where([p], p.status == :active)
    |> preload([:default_variant, images: ^storefront_image_query()])
    |> Repo.all()
  end

  def get_storefront_product_by_slug!(slug) do
    Product
    |> where([p], p.slug == ^slug and p.status == :active)
    |> preload([:default_variant, :variants, :images])
    |> Repo.one!()
  end

  defp storefront_image_query do
    ProductImage
    |> where([i], i.status == :ready)
    |> limit(1)
  end

  def get_product!(id) do
    Product
    |> preload([:variants])
    |> Repo.get!(id)
  end

  def create_product(attrs) do
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert()
  end

  def update_product(%Product{} = product, attrs) do
    product
    |> Product.changeset(attrs)
    |> Repo.update()
  end

  def save_product_with_media(%Product{} = product, params, media_uploads) do
    changeset = change_product(product, params)

    Repo.transact(fn ->
      with {:ok, product} <- Repo.insert_or_update(changeset),
           {:ok, product_images} <- promote_media_uploads(product, media_uploads) do
        {:ok, %{product | images: product_images}}
      end
    end)
  end

  defp promote_media_uploads(%Product{} = product, media_uploads) do
    product = Repo.preload(product, :images)

    media_uploads
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn
      {%{delete: true, product_image_id: nil}, _position}, {:ok, acc} ->
        {:cont, {:ok, acc}}

      {%{product_image_id: nil} = media_upload, position}, {:ok, acc} ->
        attrs = %{
          product_id: product.id,
          temp_upload_path: media_upload.key,
          image_path: image_path(product, media_upload),
          file_name: media_upload.file_name,
          file_size: media_upload.file_size,
          file_type: media_upload.file_type,
          position: position
        }

        with {:ok, product_image} <- create_image(attrs),
             {:ok, _} <- MediaUploadPromotionWorker.enqueue(product_image) do
          {:cont, {:ok, [product_image | acc]}}
        else
          {:error, changeset} -> {:halt, {:error, changeset}}
        end

      {media_upload, position}, {:ok, acc} ->
        image = Enum.find(product.images, &(&1.id == media_upload.product_image_id))

        result =
          if media_upload.delete do
            delete_image(image)
          else
            update_image(image, %{position: position})
          end

        case result do
          {:ok, product_image} -> {:cont, {:ok, [product_image | acc]}}
          {:error, changeset} -> {:halt, {:error, changeset}}
        end
    end)
    |> case do
      {:ok, product_images} -> {:ok, Enum.reverse(product_images)}
      error -> error
    end
  end

  defp image_path(%Product{} = product, %MediaUpload{} = media_upload) do
    [_ | tail] = Path.split(media_upload.key)
    Path.join(["products", product.id, "images"] ++ tail)
  end

  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  def change_product(%Product{} = product, attrs \\ %{}) do
    Product.changeset(product, attrs)
  end

  ## Images

  def get_image!(id) do
    Repo.get!(ProductImage, id)
  end

  def create_image(attrs) do
    %ProductImage{}
    |> ProductImage.changeset(attrs)
    |> Repo.insert()
  end

  def update_image(%ProductImage{} = image, attrs) do
    image
    |> ProductImage.changeset(attrs)
    |> Repo.update()
  end

  def delete_image(%ProductImage{} = image) do
    Repo.delete(image)
  end

  def change_image(%ProductImage{} = image, attrs \\ %{}) do
    ProductImage.changeset(image, attrs)
  end

  ## Categories

  def list_categories do
    Repo.all(Category)
  end

  def get_category!(id) do
    Repo.get!(Category, id)
  end

  def create_category(attrs) do
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
  end

  def update_category(%Category{} = category, attrs) do
    category
    |> Category.changeset(attrs)
    |> Repo.update()
  end

  def delete_category(%Category{} = category) do
    Repo.delete(category)
  end

  def change_category(%Category{} = category, attrs \\ %{}) do
    Category.changeset(category, attrs)
  end
end
