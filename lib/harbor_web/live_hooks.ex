defmodule HarborWeb.LiveHooks do
  @moduledoc """
  Adds a LiveView hook to set the current path in assigns.
  """
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  def on_mount(:global, _params, _session, socket) do
    {:cont, attach_hook(socket, :assign_current_path, :handle_params, &assign_current_path/3)}
  end

  defp assign_current_path(_params, url, socket) do
    uri =
      url
      |> URI.parse()
      |> current_path()

    {:cont, assign(socket, :current_path, uri)}
  end

  defp current_path(%URI{path: path, query: query}) when is_binary(path) and is_binary(query) do
    path <> "?" <> query
  end

  defp current_path(%URI{path: path}) when is_binary(path), do: path
  defp current_path(_uri), do: "/"
end
