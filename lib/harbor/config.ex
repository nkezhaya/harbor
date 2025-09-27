defmodule Harbor.Config do
  @moduledoc """
  Centralizes access to runtime configuration values that the application
  depends on at runtime. Keeping these helpers in one module makes it easy to
  mock or extend configuration lookups while avoiding multiple direct
  `Application.get_env/2` calls.
  """

  def tax_provider do
    {provider, _} = Application.get_env(:harbor, :tax_provider)
    provider
  end

  def s3_bucket do
    Application.get_env(:harbor, :s3_bucket) ||
      raise """
      Expected an S3 bucket to be configured. Configure one with:

          config :harbor, :s3_bucket, "my-bucket"
      """
  end
end
