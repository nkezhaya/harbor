defmodule Harbor.Web.LiveHooks do
  @moduledoc """
  Shared LiveView hooks that populate assigns used by multiple views.
  """
  import Phoenix.Component, only: [assign: 3, assign_new: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  alias Harbor.{Catalog, Checkout}
  alias Harbor.Web.CartComponents

  def on_mount(:global, _params, _session, socket) do
    {:cont, attach_hook(socket, :assign_current_path, :handle_params, &assign_current_path/3)}
  end

  def on_mount(:storefront, _params, _session, socket) do
    socket =
      socket
      |> assign_new(:root_categories, fn ->
        Catalog.list_root_categories()
      end)
      |> assign_new(:cart, fn %{current_scope: current_scope} ->
        Checkout.fetch_active_cart_with_items(current_scope)
      end)
      |> attach_hook(:cart, :handle_event, &CartComponents.hooked_event/3)

    {:cont, socket}
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
