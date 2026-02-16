# Development App
#
# Usage:
#
#     $ mix dev
#

Logger.configure(level: :debug)

Application.put_env(:phoenix, :json_library, JSON)
Application.put_env(:phoenix, :stacktrace_depth, 20)
Application.put_env(:phoenix, :plug_init_mode, :runtime)

Application.put_env(:phoenix_live_view, :debug_heex_annotations, true)
Application.put_env(:phoenix_live_view, :debug_attributes, true)
Application.put_env(:phoenix_live_view, :enable_expensive_runtime_checks, true)

Application.put_env(:logger, :default_formatter, format: "[$level] $message\n")
Application.put_env(:swoosh, :api_client, false)

Application.put_env(:ex_aws, :region, System.fetch_env!("AWS_REGION"))
Application.put_env(:ex_aws, :access_key_id, System.fetch_env!("AWS_ACCESS_KEY_ID"))
Application.put_env(:ex_aws, :secret_access_key, System.fetch_env!("AWS_SECRET_ACCESS_KEY"))

Application.put_env(:stripity_stripe, :api_key, System.fetch_env!("STRIPE_API_KEY"))

defmodule Harbor.DevRepo do
  use Ecto.Repo, otp_app: :harbor, adapter: Ecto.Adapters.Postgres
end

defmodule Harbor.DevOban do
  use Oban, otp_app: :harbor
end

defmodule Harbor.DevMailer do
  use Swoosh.Mailer, otp_app: :harbor
end

Application.put_env(:harbor, :s3_bucket, System.fetch_env!("HARBOR_S3_BUCKET"))
Application.put_env(:harbor, :cdn_url, System.fetch_env!("HARBOR_CDN_URL"))
Application.put_env(:harbor, :repo, Harbor.DevRepo)
Application.put_env(:harbor, :oban, Harbor.DevOban)
Application.put_env(:harbor, :mailer, Harbor.DevMailer)

pg_url =
  System.get_env("DATABASE_URL") || "postgres://postgres:postgres@localhost:5432/harbor_dev"

Application.put_env(:harbor, Harbor.DevRepo,
  url: pg_url,
  pool_size: System.schedulers_online() * 2,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  migration_primary_key: false,
  migration_foreign_key: [type: :binary_id],
  migration_timestamps: [type: :timestamptz],
  after_connect: {Postgrex, :query!, ["SET TIME ZONE 'UTC'", []]}
)

Application.put_env(:harbor, Harbor.DevOban,
  engine: Oban.Engines.Basic,
  queues: [media_uploads: 10, billing: 10],
  repo: Harbor.DevRepo
)

Application.put_env(:harbor, Harbor.DevMailer, adapter: Swoosh.Adapters.Local)

Application.put_env(:harbor, :ecto_repos, [Harbor.DevRepo])

port = String.to_integer(System.get_env("PORT") || "4000")

Application.put_env(:harbor, DemoWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  http: [ip: {127, 0, 0, 1}, port: port],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "jzAqJQFmbK1nWbK2SfbYVrt8/0P9i7Jzq0kD6p3M5i1R3G3k2l9mO4qvQZpYd8G1",
  live_view: [signing_salt: "3m3P4Cq5"],
  pubsub_server: Harbor.PubSub,
  render_errors: [
    formats: [html: Harbor.Web.ErrorHTML, json: Harbor.Web.ErrorJSON],
    layout: false
  ],
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:harbor, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:harbor, ~w(--watch)]}
  ],
  live_reload: [
    web_console_logger: true,
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/harbor/web/(?:controllers|live|components|router)/?.*\.(ex|heex)$"
    ]
  ]
)

defmodule DemoWeb.Router do
  use Phoenix.Router

  import Plug.Conn
  import Phoenix.Controller
  import Phoenix.LiveView.Router
  import Harbor.Web.UserAuth
  import Harbor.Web.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {Harbor.Web.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  scope "/dev" do
    pipe_through :browser

    forward "/mailbox", Plug.Swoosh.MailboxPreview
  end

  scope "/" do
    pipe_through :browser

    harbor_storefront()
    harbor_authenticated()
    harbor_admin()
  end
end

defmodule DemoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :harbor

  @session_options [
    store: :cookie,
    key: "_harbor_key",
    signing_salt: "jypyQrcR",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  plug Plug.Static,
    at: "/",
    from: :harbor,
    gzip: false,
    only: Harbor.Web.static_paths()

  socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
  plug Phoenix.LiveReloader
  plug Phoenix.CodeReloader

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug DemoWeb.Router
end

Application.ensure_all_started(:postgrex)
_ = Ecto.Adapters.Postgres.storage_up(Harbor.DevRepo.config())

{:ok, _} = Harbor.DevRepo.start_link()
Ecto.Migrator.up(Harbor.DevRepo, 1, Harbor.Migration)
Ecto.Migrator.up(Harbor.DevRepo, 2, Oban.Migration)
Harbor.DevRepo.stop()

Application.put_env(:phoenix, :serve_endpoints, true)

Application.ensure_all_started(:harbor)

Task.async(fn ->
  children = [
    Harbor.Web.Telemetry,
    Harbor.DevRepo,
    Harbor.DevOban,
    DemoWeb.Endpoint
  ]

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)
  Process.sleep(:infinity)
end)
|> Task.await(:infinity)
