defmodule Harbor.Web.PathHelpers do
  @moduledoc """
  Path helper functions for Harbor routes.
  """

  @doc """
  Returns the path for the given admin route.

  ## Examples

      admin_path(@socket)                    #=> "/admin"
      admin_path(@socket, "/products")       #=> "/admin/products"
      admin_path(conn, "/products/new")      #=> "/admin/products/new"
  """
  def admin_path(socket_or_conn, path \\ "")

  def admin_path(%Phoenix.LiveView.Socket{router: router}, path),
    do: router.__harbor_prefix__() <> path

  def admin_path(%Plug.Conn{} = conn, path),
    do: conn.private.phoenix_router.__harbor_prefix__() <> path

  @doc """
  Generates a full URL from a path string.

  Uses the endpoint from the socket or conn to build the base URL.

  ## Examples

      url(@socket, "/users/settings")  #=> "https://example.com/users/settings"
      url(conn, "/users/log-in")       #=> "https://example.com/users/log-in"
  """
  def url(%Phoenix.LiveView.Socket{endpoint: endpoint}, path),
    do: endpoint.url() <> path

  def url(%Plug.Conn{} = conn, path),
    do: Phoenix.Controller.endpoint_module(conn).url() <> path
end
