import Config

config :bcrypt_elixir, :log_rounds, 1

config :swoosh, :api_client, false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :harbor, Harbor.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "harbor_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :harbor, Harbor.Web.TestEndpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "DJPDxwrcfSImvJWlye0yth5ho+epQUDvdo2WmrGvRKNeMs0wS7jOBPgITMVIjphl",
  render_errors: [
    formats: [html: Harbor.Web.ErrorHTML, json: Harbor.Web.ErrorJSON],
    layout: false
  ],
  pubsub_server: Harbor.PubSub,
  live_view: [signing_salt: "mzGS68aG"],
  server: false

config :harbor, Harbor.Mailer, adapter: Swoosh.Adapters.Test

config :harbor, Harbor.Oban, testing: :manual

config :harbor, :s3_bucket, "test"
config :harbor, :cdn_url, "https://test.cloudfront.net"
