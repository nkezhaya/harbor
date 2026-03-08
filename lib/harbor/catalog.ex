defmodule Harbor.Catalog do
  @moduledoc """
  Catalog models the parts of the system that describe what is being sold.

  The easiest way to understand the catalog is to think about a product, e.g.
  "Men's Cotton Crewneck T-Shirt".

  The shirt itself is a [Product](`Harbor.Catalog.Product`). This is the shared
  catalog record for the item that customers recognize. It holds things like the
  name, description, brand, product type, main merchandising taxon, images, and
  the list of variants that belong to it.

  The brand, such as "Nike" or "Uniqlo", is a
  [Brand](`Harbor.Catalog.Brand`). Brands are reusable catalog records. They
  are not just free-form strings on a product.

  The kind of product the shirt is belongs to a
  [ProductType](`Harbor.Catalog.ProductType`). A product type is an internal
  authoring template. It answers questions like "what kind of thing is this?"
  and "which option dimensions and properties usually apply here?" For example,
  this item might belong to a product type called "T-Shirt".

  Where the product appears in Harbor's navigation is described by a
  [Taxon](`Harbor.Catalog.Taxon`). A taxon is a merchandising node such as
  "Apparel", "Tops", or "Summer Sale". Taxons are for Harbor's own browsing
  structure. They are separate from product type because navigation and
  classification are separate problems.

  The purchasable rows are [Variant](`Harbor.Catalog.Variant`) records. If the
  shirt is sold as Small / Black and Medium / White, those are variants. Each
  variant has its own SKU, price, inventory state, and optional tax override.
  Variants are explicit rows. Harbor does not assume every possible combination
  exists.

  The dimensions a variant can vary by are [OptionType](`Harbor.Catalog.OptionType`)
  records. Common examples are "Size" and "Color". The concrete values inside
  those dimensions are [OptionValue](`Harbor.Catalog.OptionValue`) records such
  as "S", "M", "L", "Black", and "White". These are reusable catalog vocabulary,
  not product-owned strings. A product can choose which option types it uses,
  and a variant chooses one value from each active option type.

  Not every important piece of product data should create a new SKU. Descriptive
  data that does not define a purchasable combination belongs in
  [Property](`Harbor.Catalog.Property`). Examples include "Material", "Fit", or
  "Country of Origin". Properties can apply at the product level or the variant
  level, depending on what they describe.

  Some properties use shared categorical values. For example, a property like
  "Material" might draw from a reusable set that contains "Cotton", "Wool", and
  "Linen". The shared set is a
  [PropertyValueSet](`Harbor.Catalog.PropertyValueSet`), and the individual
  choices inside it are [PropertyOption](`Harbor.Catalog.PropertyOption`)
  records.

  Product images are [ProductImage](`Harbor.Catalog.ProductImage`) records.
  Images stay attached to the product rather than to individual variants.

  In short:

    * Product: the thing being merchandised
    * Variant: a specific purchasable row
    * Brand: who made or owns it
    * ProductType: the internal template for this kind of item
    * Taxon: where it sits in Harbor's navigation
    * OptionType and OptionValue: reusable SKU dimensions like size and color
    * Property, PropertyValueSet, and PropertyOption: descriptive data that does
      not necessarily create new SKUs
    * ProductImage: media attached to the product

  This context exposes the main catalog operations, while the schema modules
  define the underlying records and relationships.
  """
  import Ecto.Query, warn: false
  import Harbor.Authorization

  alias Harbor.Accounts.Scope

  alias Harbor.Catalog.{
    Brand,
    Product,
    ProductImage,
    ProductQuery,
    ProductTaxon,
    ProductType,
    Taxon,
    Variant
  }

  alias Harbor.Catalog.Forms.{MediaUpload, MediaUploadPromotionWorker}
  alias Harbor.Repo

  ## Products

  @doc """
  Returns a paginated list of products matching the given params.

  Non-admin scopes are restricted to active products. Results include
  the `:default_variant` and first ready `:images` preloaded.
  """
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
    enabled_variants_query =
      Variant
      |> where([v], v.enabled)
      |> order_by([v], asc: v.inserted_at)
      |> preload([:option_values, variant_option_values: [:option_type, :option_value]])

    Product
    |> where([p], p.slug == ^slug and p.status == :active)
    |> preload([
      :brand,
      :primary_taxon,
      default_variant: [:option_values, variant_option_values: [:option_type, :option_value]],
      variants: ^enabled_variants_query,
      images: ^storefront_gallery_query()
    ])
    |> Repo.one!()
  end

  defp storefront_image_query do
    ProductImage
    |> where([i], i.status == :ready)
    |> order_by([i], asc: i.position)
    |> limit(1)
  end

  defp storefront_gallery_query do
    ProductImage
    |> where([i], i.status == :ready)
    |> order_by([i], asc: i.position)
  end

  def get_product!(id) do
    Product
    |> Repo.get!(id)
    |> preload_product()
  end

  def create_product(attrs) do
    Repo.transact(fn ->
      persist_product(%Product{}, attrs)
    end)
  end

  def update_product(%Product{} = product, attrs) do
    Repo.transact(fn ->
      persist_product(product, attrs)
    end)
  end

  def save_product_with_media(%Product{} = product, params, media_uploads) do
    Repo.transact(fn ->
      with {:ok, product} <- persist_product(product, params),
           {:ok, product_images} <- promote_media_uploads(product, media_uploads) do
        {:ok, preload_product(%{product | images: product_images})}
      end
    end)
  end

  defp persist_product(%Product{} = product, attrs) do
    changeset = change_product(product, attrs)

    with {:ok, product} <- Repo.insert_or_update(changeset),
         {:ok, product} <- sync_primary_taxon(product),
         {:ok, product} <- ensure_default_variant(product) do
      {:ok, preload_product(product)}
    end
  end

  ## TODO: Temp hack while admin UI gets changes
  defp sync_primary_taxon(%Product{primary_taxon_id: nil} = product), do: {:ok, product}

  defp sync_primary_taxon(%Product{} = product) do
    Repo.delete_all(
      from(product_taxon in ProductTaxon,
        where: product_taxon.product_id == ^product.id,
        where: product_taxon.taxon_id != ^product.primary_taxon_id
      )
    )

    %ProductTaxon{}
    |> ProductTaxon.changeset(%{
      product_id: product.id,
      taxon_id: product.primary_taxon_id,
      position: 0
    })
    |> Repo.insert(
      on_conflict: [set: [position: 0]],
      conflict_target: [:product_id, :taxon_id]
    )
    |> case do
      {:ok, _product_taxon} -> {:ok, product}
      error -> error
    end
  end

  defp ensure_default_variant(%Product{} = product) do
    product = Repo.preload(product, :variants)

    default_variant =
      Enum.find(product.variants, &(&1.id == product.default_variant_id)) ||
        Enum.find(product.variants, & &1.enabled) ||
        List.first(product.variants)

    cond do
      is_nil(default_variant) ->
        {:ok, product}

      product.default_variant_id == default_variant.id ->
        {:ok, product}

      true ->
        product
        |> Product.changeset(%{default_variant_id: default_variant.id})
        |> Repo.update()
    end
  end

  defp preload_product(%Product{} = product) do
    Repo.preload(product, [
      :brand,
      :product_type,
      :primary_taxon,
      :default_variant,
      :images,
      product_taxons: :taxon,
      variants: [:option_values, variant_option_values: [:option_type, :option_value]],
      product_option_types: [option_type: :values],
      product_option_values: [:option_type, :option_value],
      product_property_values: [:property, :property_option]
    ])
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

  ## Brands

  def list_brands do
    Brand
    |> order_by(asc: :position, asc: :name)
    |> Repo.all()
  end

  ## Product Types

  def list_product_types do
    ProductType
    |> order_by(asc: :name)
    |> Repo.all()
  end

  def get_product_type!(id) do
    Repo.get!(ProductType, id)
  end

  def create_product_type(attrs) do
    %ProductType{}
    |> ProductType.changeset(attrs)
    |> Repo.insert()
  end

  def change_product_type(%ProductType{} = product_type, attrs \\ %{}) do
    ProductType.changeset(product_type, attrs)
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

  ## Taxons

  def list_root_taxons do
    Taxon
    |> where([taxon], is_nil(taxon.parent_id))
    |> order_by(asc: :position, asc: :name)
    |> Repo.all()
  end

  def list_taxons do
    Taxon
    |> order_by(asc: :position, asc: :name)
    |> preload(:parent)
    |> Repo.all()
  end

  def get_taxon!(id) do
    Taxon
    |> preload(:parent)
    |> Repo.get!(id)
  end

  def get_taxon!(%Scope{} = _scope, id) do
    Taxon
    |> preload(:parent)
    |> Repo.get!(id)
  end

  def create_taxon(%Scope{} = scope, attrs) do
    ensure_admin!(scope)

    %Taxon{}
    |> Taxon.changeset(attrs)
    |> Repo.insert()
    |> preload_taxon_result()
  end

  def update_taxon(%Scope{} = scope, %Taxon{} = taxon, attrs) do
    ensure_admin!(scope)

    taxon
    |> Taxon.changeset(attrs)
    |> Repo.update()
    |> preload_taxon_result()
  end

  defp preload_taxon_result({:ok, taxon}) do
    {:ok, Repo.preload(taxon, :parent)}
  end

  defp preload_taxon_result(error) do
    error
  end

  def delete_taxon(%Scope{} = scope, %Taxon{} = taxon) do
    ensure_admin!(scope)
    Repo.delete(taxon)
  end

  def change_taxon(%Scope{} = scope, %Taxon{} = taxon, attrs \\ %{}) do
    ensure_admin!(scope)
    Taxon.changeset(taxon, attrs)
  end
end
