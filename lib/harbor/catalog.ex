defmodule Harbor.Catalog do
  @moduledoc """
  Catalog models the parts of the system that describe what is being sold.

  The easiest way to understand the catalog is to think about a product, e.g.
  "Men's Cotton Crewneck T-Shirt".

  The shirt itself is a [Product](`Harbor.Catalog.Product`). This is the shared
  catalog record for the item that customers recognize. It holds things like the
  name, description, brand, product type, main merchandising taxon, images,
  product-owned options, and the list of variants that belong to it.

  The brand, such as "Nike" or "Uniqlo", is a
  [Brand](`Harbor.Catalog.Brand`). Brands are reusable catalog records. They
  are not just free-form strings on a product.

  The kind of product the shirt is belongs to a
  [ProductType](`Harbor.Catalog.ProductType`). A product type is a lightweight
  internal classification and template. It answers questions like "what kind of
  thing is this?" and carries default tax information and any property-template
  behavior Harbor still wants.

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

  The variation structure itself is product-owned. A
  [ProductOption](`Harbor.Catalog.ProductOption`) is one option on one product,
  such as Size or Color. Its concrete values are
  [ProductOptionValue](`Harbor.Catalog.ProductOptionValue`) records such as S,
  M, Black, or White. A variant chooses one value for each product option
  through [VariantOptionValue](`Harbor.Catalog.VariantOptionValue`) rows.

  Not every important piece of product data should create a new SKU. Descriptive
  data that does not define a purchasable combination belongs in
  [Property](`Harbor.Catalog.Property`). Examples include Material, Fit, or
  Country of Origin. Properties can apply at the product level or the variant
  level, depending on what they describe.

  Some properties use shared categorical values. For example, a property like
  Material might draw from a reusable set that contains Cotton, Wool, and
  Linen. The shared set is a [PropertyValueSet](`Harbor.Catalog.PropertyValueSet`),
  and the individual choices inside it are
  [PropertyOption](`Harbor.Catalog.PropertyOption`) records.

  Product images are [ProductImage](`Harbor.Catalog.ProductImage`) records.
  Images stay attached to the product rather than to individual variants.
  """
  import Ecto.Query
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
  the `:master_variant` and first ready `:images` preloaded.
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
    |> preload([:master_variant, images: ^storefront_image_query()])
    |> Repo.paginate(query)
  end

  def get_storefront_product_by_slug!(slug) do
    variant_preload = [
      :option_values,
      variant_option_values: [:product_option, :product_option_value]
    ]

    Product
    |> where([p], p.slug == ^slug and p.status == :active)
    |> preload([
      :brand,
      :primary_taxon,
      product_options: :values,
      images: ^storefront_gallery_query(),
      master_variant: ^variant_preload,
      enabled_variants: ^variant_preload
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
      persist_product(%Product{product_taxons: []}, attrs)
    end)
  end

  def update_product(%Product{} = product, attrs) do
    Repo.transact(fn ->
      persist_product(product, attrs)
    end)
  end

  def update_product_variants(%Product{} = product, attrs) do
    Repo.transact(fn ->
      persist_product_variants(product, attrs)
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

  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  def change_product(%Product{} = product, attrs \\ %{}) do
    product_with_master_variant_changeset(product, attrs)
  end

  def change_product_variants(%Product{} = product, attrs \\ %{}) do
    product =
      Repo.preload(
        product,
        [
          product_options: :values,
          variants: {non_master_variants_query(product), :variant_option_values}
        ],
        force: true
      )

    Product.variant_changeset(product, attrs)
  end

  # FIXME: This function is doing a ton of duplicate work. Should be drastically
  # simplified after master_variant_id is removed.
  defp persist_product(%Product{} = product, attrs) do
    changeset =
      product
      |> product_with_master_variant_changeset(attrs)
      |> sync_taxons()

    if changeset.valid? do
      master_variant_changeset = Ecto.Changeset.get_assoc(changeset, :master_variant, :changeset)

      with {:ok, product} <-
             product
             |> product_changeset(attrs)
             |> sync_taxons()
             |> Repo.insert_or_update(),
           {:ok, product} <- upsert_master_variant(product, master_variant_changeset) do
        {:ok, preload_product(product)}
      end
    else
      {:error, changeset}
    end
  end

  defp persist_product_variants(%Product{} = product, attrs) do
    with {:ok, product} <-
           product
           |> change_product_variants(attrs)
           |> Repo.update() do
      {:ok, preload_product(product)}
    end
  end

  defp upsert_master_variant(%Product{} = product, master_variant_changeset) do
    product = Repo.preload(product, :master_variant)

    case product.master_variant do
      nil ->
        with {:ok, master_variant} <-
               create_master_variant(product, master_variant_changes(master_variant_changeset)) do
          product
          |> Ecto.Changeset.change(master_variant_id: master_variant.id)
          |> Repo.update()
        end

      master_variant ->
        master_variant
        |> Variant.changeset(master_variant_changes(master_variant_changeset))
        |> Repo.update()
        |> case do
          {:ok, _master_variant} -> {:ok, product}
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  defp product_changeset(%Product{} = product, attrs) do
    product =
      Repo.preload(
        product,
        [
          :product_taxons,
          variants: non_master_variants_query(product),
          product_options: :values
        ],
        force: true
      )

    product
    |> put_taxon_ids()
    |> Product.changeset(attrs)
  end

  defp product_with_master_variant_changeset(%Product{} = product, attrs) do
    product =
      Repo.preload(
        product,
        [
          :product_taxons,
          :master_variant,
          variants: non_master_variants_query(product),
          product_options: :values
        ],
        force: true
      )

    product
    |> put_taxon_ids()
    |> put_master_variant()
    |> Product.with_master_variant_changeset(attrs)
  end

  defp create_master_variant(%Product{} = product, attrs) do
    %Variant{product_id: product.id, tax_code_id: product.tax_code_id, price: Money.new(:USD, 0)}
    |> Variant.changeset(attrs)
    |> Repo.insert()
  end

  defp put_master_variant(%Product{} = product) do
    default_master_variant = %Variant{tax_code_id: product.tax_code_id, price: Money.new(:USD, 0)}
    %{product | master_variant: product.master_variant || default_master_variant}
  end

  # TODO: Should be removed after master_variant_id is removed.
  defp master_variant_changes(master_variant_changeset) do
    Enum.reduce(
      [:sku, :price, :quantity_available, :enabled, :inventory_policy, :tax_code_id],
      %{},
      fn field, changes ->
        case Ecto.Changeset.fetch_change(master_variant_changeset, field) do
          {:ok, value} -> Map.put(changes, field, value)
          :error -> changes
        end
      end
    )
  end

  # TODO: Should be removed after master_variant_id is removed.
  defp non_master_variants_query(%Product{master_variant_id: nil}) do
    Variant
  end

  defp non_master_variants_query(%Product{} = product) do
    where(Variant, [variant], variant.id != ^product.master_variant_id)
  end

  defp sync_taxons(changeset) do
    existing_product_taxons =
      changeset
      |> Ecto.Changeset.get_assoc(:product_taxons, :struct)
      |> Map.new(&{&1.taxon_id, &1})

    primary_taxon_id = Ecto.Changeset.get_field(changeset, :primary_taxon_id)

    taxon_ids = Ecto.Changeset.get_field(changeset, :taxon_ids) || []
    taxon_ids = Enum.uniq(taxon_ids)

    taxon_ids =
      cond do
        is_nil(primary_taxon_id) ->
          taxon_ids

        primary_taxon_id in taxon_ids ->
          taxon_ids

        true ->
          [primary_taxon_id | taxon_ids]
      end

    product_taxons =
      taxon_ids
      |> Enum.with_index()
      |> Enum.map(fn {taxon_id, position} ->
        Map.get(existing_product_taxons, taxon_id, %ProductTaxon{})
        |> ProductTaxon.changeset(%{taxon_id: taxon_id, position: position})
      end)

    Ecto.Changeset.put_assoc(changeset, :product_taxons, product_taxons)
  end

  defp preload_product(%Product{} = product) do
    Repo.preload(
      product,
      [
        :brand,
        :product_type,
        :primary_taxon,
        :images,
        master_variant: [
          :option_values,
          variant_option_values: [:product_option, :product_option_value]
        ],
        product_taxons: :taxon,
        product_options: :values,
        variants:
          {non_master_variants_query(product),
           [
             :option_values,
             variant_option_values: [:product_option, :product_option_value]
           ]},
        product_property_values: [:property, :property_option]
      ],
      force: true
    )
  end

  defp put_taxon_ids(%Product{} = product) do
    taxon_ids =
      cond do
        Ecto.assoc_loaded?(product.product_taxons) and product.product_taxons != [] ->
          Enum.map(product.product_taxons, & &1.taxon_id)

        is_nil(product.primary_taxon_id) ->
          []

        true ->
          [product.primary_taxon_id]
      end

    %{product | taxon_ids: taxon_ids}
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
