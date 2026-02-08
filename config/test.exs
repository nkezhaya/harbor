import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :harbor, Harbor.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "harbor_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# Point Harbor's VerifiedRoutes at the test endpoint
config :harbor, :verified_routes_endpoint, Harbor.Web.TestEndpoint

# Test endpoint configuration (Harbor.Web.TestEndpoint defined in test/support/)
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

# In test we don't send emails
config :harbor, Harbor.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

config :harbor, Harbor.Oban, testing: :manual

config :harbor, :s3_bucket, "test"
config :harbor, :cdn_url, "https://test.cloudfront.net"
