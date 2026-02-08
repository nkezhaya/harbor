import Config

# Configure your database
config :harbor, Harbor.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "harbor_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Point Harbor's VerifiedRoutes at the dev endpoint (defined in dev.exs)
config :harbor, :verified_routes_endpoint, DemoWeb.Endpoint

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include debug annotations and locations in rendered markup.
  # Changing this configuration will require mix clean and a full recompile.
  debug_heex_annotations: true,
  debug_attributes: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

if File.exists?("config/dev.local.exs") do
  import_config("dev.local.exs")
end
