defmodule Harbor.Config do
  @moduledoc """
  Centralizes access to runtime configuration values that the application
  depends on at runtime. Keeping these helpers in one module makes it easy to
  mock or extend configuration lookups while avoiding multiple direct
  `Application.get_env/2` calls.
  """

  def repo do
    Application.fetch_env!(:harbor, :repo)
  end

  def tax_provider do
    Application.get_env(:harbor, :tax_provider, Harbor.Tax.TaxProvider.Stripe)
  end

  def payment_provider do
    Application.get_env(:harbor, :payment_provider, Harbor.Billing.PaymentProvider.Stripe)
  end

  def s3_bucket do
    Application.fetch_env!(:harbor, :s3_bucket)
  end

  def cdn_url do
    Application.fetch_env!(:harbor, :cdn_url)
  end

  def cache do
    Application.get_env(:harbor, :cache, Harbor.Cache.ETS)
  end

  @required_keys [:repo, :oban, :mailer, :s3_bucket, :cdn_url]

  def validate! do
    missing =
      for key <- @required_keys,
          is_nil(Application.get_env(:harbor, key)),
          do: key

    if missing != [] do
      raise ArgumentError, """
      missing required Harbor configuration keys: #{inspect(missing)}

      Ensure the following are set in your config:

          config :harbor, :repo, MyApp.Repo
          config :harbor, :oban, MyApp.Oban
          config :harbor, :mailer, MyApp.Mailer
          config :harbor, :s3_bucket, "my-bucket"
          config :harbor, :cdn_url, "https://my-distribution.cloudfront.net"
      """
    end

    :ok
  end
end
