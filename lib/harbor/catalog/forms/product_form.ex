defmodule Harbor.Catalog.Forms.ProductForm do
  use Ecto.Schema
  import Ecto.Changeset

  alias Harbor.Catalog.Product
  alias Harbor.Uploader.ProductAsset

  embedded_schema do
    embeds_one :product, Product
    embeds_many :product_assets, ProductAsset
  end

  def changeset(product_form, attrs) do
    product_form
    |> cast(attrs, [])
    |> cast_embed(:product)
    |> cast_embed(:product_assets)
  end
end
