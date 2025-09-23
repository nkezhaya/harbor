defmodule HarborWeb.Admin.ProductLive.Show do
  @moduledoc """
  Admin LiveView for displaying product details.
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
      live_action={@live_action}
    >
      <.header>
        Product {@product.id}
        <:subtitle>This is a product record from your database.</:subtitle>
        <:actions>
          <.button navigate={~p"/admin/products"}>
            <.icon name="hero-arrow-left" />
            <span class="sr-only">Back to products</span>
          </.button>
          <.button variant="primary" navigate={~p"/admin/products/#{@product}/edit?return_to=show"}>
            <.icon name="hero-pencil-square" /> Edit product
          </.button>
        </:actions>
      </.header>

      <.list>
        <:item title="Name">{@product.name}</:item>
        <:item title="Slug">{@product.slug}</:item>
        <:item title="Description">{@product.description}</:item>
        <:item title="Status">{@product.status}</:item>
      </.list>
    </AdminLayouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Show Product")
     |> assign(:product, Catalog.get_product!(id))}
  end
end
