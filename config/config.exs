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
  migration_timestamps: [type: :timestamptz],
  # Postgrex casts DateTime objects to timestamp, instead of timestamptz, which
  # causes comparisons to fail when the connection is set to a non-UTC time zone.
  # Setting it to UTC immediately after connecting prevents errors in dev and
  # test.
  after_connect: {Postgrex, :query!, ["SET TIME ZONE 'UTC'", []]}

config :harbor, Harbor.Mailer, adapter: Swoosh.Adapters.Local

config :harbor, Harbor.Oban,
  engine: Oban.Engines.Basic,
  queues: [media_uploads: 10, billing: 10],
  repo: Harbor.Repo

config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

if config_env() == :dev do
  config :phoenix, :json_library, JSON
  config :ex_aws, json_codec: JSON

  config :esbuild,
    version: "0.25.4",
    harbor: [
      args:
        ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
    ]

  config :tailwind,
    version: "4.1.7",
    harbor: [
      args: ~w(
        --input=assets/css/app.css
        --output=priv/static/assets/css/app.css
      ),
      cd: Path.expand("..", __DIR__)
    ]

  config :harbor, :tax_provider, {:stripe, Harbor.Tax.TaxProvider.Stripe}
  config :harbor, :payment_provider, {:stripe, Harbor.Billing.PaymentProvider.Stripe}
end

if config_env() == :test do
  import_config("test.exs")
end
