defmodule Harbor.Uploader.ProductImage do
  @moduledoc """
  Waffle uploader definition for product images.
  """
  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original]

  def storage_dir(_version, {_file, scope}) do
    "uploads/images/#{scope.id}"
  end
end
