defmodule HarborWeb.ImageHelpers do
  @moduledoc """
  Convenience helpers for rendering media hosted on the CDN.
  """
  alias Harbor.Catalog.Forms.MediaUpload
  alias Harbor.Catalog.ProductImage
  alias Harbor.Config

  def media_upload_url(%MediaUpload{} = media_upload) do
    uri = URI.parse("#{Config.cdn_url()}/#{media_upload.key}")
    query = %{width: 250, height: 250} |> URI.encode_query()
    uri = %{uri | query: query}

    URI.to_string(uri)
  end

  def product_image_url(%ProductImage{} = product_image, opts \\ []) do
    uri = URI.parse("#{Config.cdn_url()}/#{product_image.image_path}")
    width = Keyword.get(opts, :width, 250)
    height = Keyword.get(opts, :height, 250)
    query = %{width: width, height: height} |> URI.encode_query()
    uri = %{uri | query: query}

    URI.to_string(uri)
  end
end
