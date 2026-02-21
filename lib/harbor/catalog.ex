defmodule Harbor.Catalog do
  @moduledoc """
  The Catalog context.
  """
  import Ecto.Query, warn: false
  import Harbor.Authorization

  alias Harbor.Accounts.Scope
  alias Harbor.Catalog.{Category, Product, ProductImage, ProductQuery}
  alias Harbor.Catalog.Forms.{MediaUpload, MediaUploadPromotionWorker}
  alias Harbor.Repo

  ## Products

  @spec list_products(Scope.t(), map()) :: %{
          entries: [Product.t()],
          page: pos_integer(),
          per_page: pos_integer(),
          total: non_neg_integer(),
          total_pages: pos_integer()
        }
  def list_products(%Scope{} = scope, params \\ %{}) do
    query = ProductQuery.new(scope, params)

    Product
    |> ProductQuery.apply(query)
    |> preload([:default_variant, images: ^storefront_image_query()])
    |> Repo.paginate(query)
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
    |> preload([:default_variant, :variants])
    |> Repo.get!(id)
  end

  def create_product(attrs) do
    Repo.transact(fn ->
      changeset = change_product(%Product{}, attrs)

      with {:ok, product} <- Repo.insert(changeset) do
        put_new_default_variant(product)
      end
    end)
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
           {:ok, product} <- put_new_default_variant(product),
           {:ok, product_images} <- promote_media_uploads(product, media_uploads) do
        {:ok, %{product | images: product_images}}
      end
    end)
  end

  defp put_new_default_variant(%{default_variant_id: nil, variants: [variant | _]} = product) do
    with {:ok, product} <- update_product(product, %{default_variant_id: variant.id}) do
      {:ok, Repo.preload(product, :default_variant)}
    end
  end

  defp put_new_default_variant(product), do: {:ok, product}

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

  def list_root_categories do
    Category
    |> where([c], is_nil(c.parent_id))
    |> order_by(asc: :position)
    |> Repo.all()
  end

  def list_categories(%Scope{} = scope) do
    ensure_admin!(scope)

    Category
    |> order_by(asc: :position)
    |> preload([:parent, :tax_code])
    |> Repo.all()
  end

  def get_category!(_scope, id) do
    Category
    |> preload([:parent, :tax_code])
    |> Repo.get!(id)
  end

  def create_category(%Scope{} = scope, attrs) do
    ensure_admin!(scope)

    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert()
    |> preload_result()
  end

  def update_category(%Scope{} = scope, %Category{} = category, attrs) do
    ensure_admin!(scope)

    category
    |> Category.changeset(attrs)
    |> Repo.update()
    |> preload_result()
  end

  defp preload_result({:ok, category}) do
    {:ok, Repo.preload(category, [:parent, :tax_code])}
  end

  defp preload_result(error) do
    error
  end

  def delete_category(%Scope{} = scope, %Category{} = category) do
    ensure_admin!(scope)
    Repo.delete(category)
  end

  def change_category(%Scope{} = scope, %Category{} = category, attrs \\ %{}) do
    ensure_admin!(scope)
    Category.changeset(category, attrs)
  end
end
