defmodule Harbor.Catalog do
  @moduledoc """
  The Catalog context.
  """
  import Ecto.Query, warn: false

  alias Harbor.Repo
  alias Harbor.Catalog.{Category, Product, ProductImage}
  alias Harbor.Catalog.Forms.ProductForm

  ## Products

  def list_products do
    Product
    |> preload([:variants])
    |> Repo.all()
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

  def delete_product(%Product{} = product) do
    Repo.delete(product)
  end

  def change_product(%Product{} = product, attrs \\ %{}) do
    Product.changeset(product, attrs)
  end

  ## Product Form

  def build_product_form(attrs \\ %{}) do
    %ProductForm{}
    |> change_product_form(attrs)
    |> Ecto.Changeset.apply_changes()
  end

  def change_product_form(product_form, attrs) do
    ProductForm.changeset(product_form, attrs)
  end

  ## Images

  def list_product_images do
    Repo.all(ProductImage)
  end

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
