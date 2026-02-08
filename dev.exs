# Development App
#
# Usage:
#
#     $ iex -S mix run dev.exs
#

require Logger
Logger.configure(level: :debug)

case Application.stop(:harbor) do
  :ok -> :ok
  {:error, {:not_started, :harbor}} -> :ok
end

Application.put_env(:phoenix, :json_library, JSON)
Application.put_env(:phoenix, :stacktrace_depth, 20)
Application.put_env(:phoenix, :plug_init_mode, :runtime)

Application.put_env(:phoenix_live_view, :debug_heex_annotations, true)
Application.put_env(:phoenix_live_view, :debug_attributes, true)
Application.put_env(:phoenix_live_view, :enable_expensive_runtime_checks, true)

Application.put_env(:logger, :default_formatter, format: "[$level] $message\n")
Application.put_env(:swoosh, :api_client, false)

db_url =
  System.get_env("DATABASE_URL") || "postgres://postgres:postgres@localhost:5432/harbor_dev"

repo_config =
  :harbor
  |> Application.get_env(Harbor.Repo, [])
  |> Keyword.merge(
    url: db_url,
    pool_size: System.schedulers_online() * 2,
    stacktrace: true,
    show_sensitive_data_on_connection_error: true
  )

Application.put_env(:harbor, Harbor.Repo, repo_config)

port = String.to_integer(System.get_env("PORT") || "4000")

endpoint_config = [
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
]

Application.put_env(:harbor, DemoWeb.Endpoint, endpoint_config ++ [server: true])

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

  pipeline :admin_layout do
    plug :put_root_layout, html: {Harbor.Web.AdminLayouts, :root}
  end

  scope "/dev" do
    pipe_through :browser

    forward "/mailbox", Plug.Swoosh.MailboxPreview
  end

  scope "/" do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{Harbor.Web.UserAuth, :require_authenticated}] do
      harbor_routes(:authenticated)
    end

    scope "/admin" do
      pipe_through [:admin_layout]

      live_session :require_authenticated_admin,
        on_mount: [
          {Harbor.Web.UserAuth, :require_admin},
          {Harbor.Web.LiveHooks, :global}
        ] do
        harbor_routes(:admin)
      end
    end
  end

  scope "/" do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [
        {Harbor.Web.UserAuth, :mount_current_scope},
        {Harbor.Web.LiveHooks, :global},
        {Harbor.Web.LiveHooks, :storefront}
      ] do
      harbor_routes(:public)
    end
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
    gzip: not code_reloading?,
    only: Harbor.Web.static_paths()

  if code_reloading? do
    socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket
    plug Phoenix.LiveReloader
    plug Phoenix.CodeReloader
    plug Phoenix.Ecto.CheckRepoStatus, otp_app: :harbor
  end

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
_ = Ecto.Adapters.Postgres.storage_up(Harbor.Repo.config())

migrations_path = Path.join([Path.dirname(__ENV__.file), "priv", "repo", "migrations"])

{:ok, _} = Harbor.Repo.start_link()
Ecto.Migrator.run(Harbor.Repo, migrations_path, :up, all: true, log_migrations_sql: true)
Harbor.Repo.stop()

Task.async(fn ->
  children = [
    Harbor.Web.Telemetry,
    Harbor.Repo,
    Harbor.Oban,
    {Phoenix.PubSub, name: Harbor.PubSub},
    DemoWeb.Endpoint
  ]

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)
  Process.sleep(:infinity)
end)
|> Task.await(:infinity)
