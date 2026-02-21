defmodule Harbor.Web.ProductLive.Index do
  @moduledoc """
  Storefront product listing page.
  """
  use Harbor.Web, :live_view

  alias Harbor.Catalog
  alias Harbor.Catalog.ProductQuery

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.current_scope
    query = ProductQuery.new(scope, params)
    result = Catalog.list_products(scope, params)

    {:noreply,
     assign(socket,
       query: query,
       products: result.entries,
       total_pages: result.total_pages
     )}
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
      <h2 class="sr-only">Products</h2>

      <div class="grid grid-cols-1 gap-x-6 gap-y-10 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 xl:gap-x-8">
        <StoreComponents.product_card :for={product <- @products} product={product} />
      </div>
    </Layouts.app>
    """
  end
end
