# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :harbor, :scopes,
  user: [
    default: true,
    module: Harbor.Accounts.Scope,
    assign_key: :current_scope,
    access_path: [:user, :id],
    schema_key: :user_id,
    schema_type: :binary_id,
    schema_table: :users,
    test_data_fixture: Harbor.AccountsFixtures,
    test_setup_helper: :register_and_log_in_user
  ]

config :harbor,
  ecto_repos: [Harbor.Repo],
  binary_id: true,
  generators: [timestamp_type: :utc_datetime_usec]

config :harbor, Harbor.Repo,
  migration_primary_key: false,
  migration_foreign_key: [type: :binary_id],
  migration_timestamps: [type: :timestamptz]

# Postgrex casts DateTime objects to timestamp, instead of timestamptz, which
# causes comparisons to fail when the connection is set to a non-UTC time zone.
# Setting it to UTC immediately after connecting prevents errors in dev and
# test.
config :harbor, Harbor.Repo, after_connect: {Postgrex, :query!, ["SET TIME ZONE 'UTC'", []]}

# Configures the endpoint
config :harbor, HarborWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: HarborWeb.ErrorHTML, json: HarborWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Harbor.PubSub,
  live_view: [signing_salt: "mzGS68aG"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :harbor, Harbor.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  harbor: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  harbor: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :json_library, JSON

config :harbor, Oban,
  engine: Oban.Engines.Basic,
  queues: [media_uploads: 10, billing: 10],
  repo: Harbor.Repo

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
