defmodule HarborWeb.Admin.ProductLive.Index do
  @moduledoc """
  Admin LiveView for listing and managing products.
  """
  use HarborWeb, :live_view

  alias Harbor.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <AdminLayouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Listing Products
        <:actions>
          <.button variant="primary" navigate={~p"/admin/products/new"}>
            <.icon name="hero-plus" /> New Product
          </.button>
        </:actions>
      </.header>

      <.table
        id="products"
        rows={@streams.products}
        row_click={fn {_id, product} -> JS.navigate(~p"/admin/products/#{product}") end}
      >
        <:col :let={{_id, product}} label="Name">{product.name}</:col>
        <:col :let={{_id, product}} label="Slug">{product.slug}</:col>
        <:col :let={{_id, product}} label="Description">{product.description}</:col>
        <:col :let={{_id, product}} label="Status">{product.status}</:col>
        <:action :let={{_id, product}}>
          <div class="sr-only">
            <.link navigate={~p"/admin/products/#{product}"}>Show</.link>
          </div>
          <.link navigate={~p"/admin/products/#{product}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, product}}>
          <.link
            phx-click={JS.push("delete", value: %{id: product.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </AdminLayouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Products")
     |> stream(:products, Catalog.list_products())}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    product = Catalog.get_product!(id)
    {:ok, _} = Catalog.delete_product(product)

    {:noreply, stream_delete(socket, :products, product)}
  end
end
