defmodule HarborWeb.CheckoutLive.Form do
  @moduledoc """
  Placeholder view for the checkout page.
  """
  use HarborWeb, :live_view

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
      <h1>Checkout</h1>
    </Layouts.app>
    """
  end
end
