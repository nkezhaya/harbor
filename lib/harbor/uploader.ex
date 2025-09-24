defmodule Harbor.Uploader do
  defmacro __using__(_opts \\ []) do
    quote do
      use Waffle.Definition
      use Waffle.Ecto.Definition

      Module.put_attribute(__MODULE__, :versions, [:original])

      def bucket do
        Application.get_env(:harbor, :s3_bucket) ||
          raise """
          Expected an S3 bucket to be configured. Configure one with:

              config :harbor, :s3_bucket, "my-bucket"
          """
      end
    end
  end

  def presign_upload(entry, socket) do
    config = ExAws.Config.new(:s3)
    bucket = Application.get_env(:waffle, :bucket)
    key = "public/#{entry.client_name}"

    {:ok, url} =
      ExAws.S3.presigned_url(config, :put, bucket, key,
        expires_in: 3600,
        query_params: [{"Content-Type", entry.client_type}]
      )

    {:ok, %{uploader: "S3", key: key, url: url}, socket}
  end
end
