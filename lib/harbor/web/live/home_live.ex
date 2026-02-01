defmodule Harbor.Web.HomeLive do
  @moduledoc """
  Provides the root LiveView for the storefront.
  """
  use Harbor.Web, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      root_categories={@root_categories}
      cart={@cart}
    >
      <h1>Home</h1>
    </Layouts.app>
    """
  end
end
