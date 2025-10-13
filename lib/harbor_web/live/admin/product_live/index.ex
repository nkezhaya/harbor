defmodule HarborWeb.Admin.ProductLive.Index do
  @moduledoc """
  Admin LiveView for listing and managing products.
  """
  use HarborWeb, :live_view

  alias Harbor.Catalog

  @impl true
  def render(assigns) do
    ~H"""
    <AdminLayouts.app
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      current_path={@current_path}
    >
      <.header :if={not @products_empty?}>
        Listing Products
        <:actions>
          <.button variant="primary" navigate={~p"/admin/products/new"}>
            <.icon name="hero-plus" /> New Product
          </.button>
        </:actions>
      </.header>

      <div :if={@products_empty?} class="mt-8">
        <.empty_state icon="hero-shopping-bag" action_label="New Product">
          <:header>No products</:header>
          <:subheader>Add your first product to start building your catalog.</:subheader>
        </.empty_state>
      </div>

      <.table
        :if={!@products_empty?}
        id="products"
        rows={@streams.products}
        row_click={fn {_id, product} -> JS.navigate(~p"/admin/products/#{product}") end}
      >
        <:col :let={{_id, product}} label="Name">{product.name}</:col>
        <:col :let={{_id, product}} label="Description">{product.description}</:col>
        <:col :let={{_id, product}} label="Status">{product.status}</:col>
        <:action :let={{_id, product}}>
          <div class="sr-only">
            <.link navigate={~p"/admin/products/#{product}"}>Show</.link>
          </div>
          <.link
            navigate={~p"/admin/products/#{product}/edit"}
            class="text-indigo-600 transition hover:text-indigo-500 dark:text-indigo-400 dark:hover:text-indigo-300"
          >
            Edit
          </.link>
        </:action>
        <:action :let={{id, product}}>
          <.link
            phx-click={JS.push("delete", value: %{id: product.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
            class="text-red-600 transition hover:text-red-500 dark:text-red-400 dark:hover:text-red-300"
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
    products = Catalog.list_products()

    {:ok,
     socket
     |> assign(:page_title, "Listing Products")
     |> assign(:products_empty?, products == [])
     |> stream(:products, products)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    product = Catalog.get_product!(id)
    {:ok, _} = Catalog.delete_product(product)

    products = Catalog.list_products()

    {:noreply,
     socket
     |> assign(:products_empty?, products == [])
     |> stream(:products, products, reset: true)}
  end
end
