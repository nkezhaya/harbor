defmodule Harbor.Uploader.ProductAsset do
  @moduledoc """
  Waffle uploader definition for product images.
  """
  use Harbor.Uploader

  def storage_dir(_version, {_file, scope}) do
    "uploads/product_assets/#{scope.id}"
  end
end
