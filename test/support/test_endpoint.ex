defmodule Harbor.Web.TestEndpoint do
  @moduledoc false

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

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug Harbor.Web.Router
end
