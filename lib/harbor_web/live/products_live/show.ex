defmodule HarborWeb.ProductsLive.Show do
  @moduledoc """
  Storefront product detail page.
  """
  use HarborWeb, :live_view

  alias Harbor.Catalog

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _uri, socket) do
    product = Catalog.get_storefront_product_by_slug!(slug)
    {:noreply, assign(socket, product: product)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div>{@product.name}</div>
      <div>{@product.description}</div>
    </Layouts.app>
    """
  end
end
