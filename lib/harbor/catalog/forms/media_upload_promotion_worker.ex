defmodule Harbor.Catalog.Forms.MediaUploadPromotionWorker do
  @moduledoc """
  Oban worker that promotes temporary product form uploads to their permanent
  [ProductImage](`Harbor.Catalog.ProductImage`) records by copying the file from
  the staging key to the final S3 path.
  """
  use Oban.Worker, queue: :media_uploads

  alias Harbor.{Catalog, Config}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"product_image_id" => product_image_id}}) do
    product_image = Catalog.get_image!(product_image_id)
    bucket = Config.s3_bucket()

    ExAws.S3.put_object_copy(
      bucket,
      product_image.image_path,
      bucket,
      product_image.temp_upload_path
    )
    |> ExAws.request!()

    :ok
  end
end
