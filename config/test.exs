import Config

config :bcrypt_elixir, :log_rounds, 1

config :swoosh, :api_client, false

config :logger, level: :warning

config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view, enable_expensive_runtime_checks: true

config :harbor,
  ecto_repos: [Harbor.TestRepo],
  repo: Harbor.TestRepo,
  oban: Harbor.TestOban,
  mailer: Harbor.TestMailer

config :harbor, Harbor.TestRepo,
  url: "postgres://postgres:postgres@localhost:5432/harbor_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2,
  migration_primary_key: false,
  migration_foreign_key: [type: :binary_id],
  migration_timestamps: [type: :timestamptz],
  after_connect: {Postgrex, :query!, ["SET TIME ZONE 'UTC'", []]}

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

config :harbor, Harbor.TestMailer, adapter: Swoosh.Adapters.Test

config :harbor, Harbor.TestOban,
  engine: Oban.Engines.Basic,
  queues: [media_uploads: 10, billing: 10],
  repo: Harbor.TestRepo,
  testing: :manual

config :harbor, :cache, Harbor.Cache.None
config :harbor, :s3_bucket, "test"
config :harbor, :cdn_url, "https://test.cloudfront.net"
