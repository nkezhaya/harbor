defmodule Harbor.Web.OrderLive.Index do
  @moduledoc """
  Storefront order history page.
  """
  use Harbor.Web, :live_view

  alias Harbor.Catalog.Variant
  alias Harbor.Orders
  alias Harbor.Orders.{Order, OrderItem}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="bg-white">
        <div class="py-16 sm:py-24">
          <div class="mx-auto max-w-7xl sm:px-2 lg:px-8">
            <div class="mx-auto max-w-2xl px-4 lg:max-w-4xl lg:px-0">
              <h1 class="text-2xl font-bold tracking-tight text-gray-900 sm:text-3xl">
                Order history
              </h1>
              <p class="mt-2 text-sm text-gray-500">
                Check the status of recent orders, manage returns, and discover similar products.
              </p>
            </div>
          </div>

          <div class="mt-16">
            <h2 class="sr-only">Recent orders</h2>
            <div class="mx-auto max-w-7xl sm:px-2 lg:px-8">
              <div
                id="orders"
                class="mx-auto max-w-2xl space-y-8 sm:px-4 lg:max-w-4xl lg:px-0"
                phx-update="stream"
              >
                <div class="hidden only:block py-12" id="orders-empty">
                  <.empty_state
                    icon="hero-shopping-bag"
                    action_label="Browse products"
                    navigate="/products"
                  >
                    <:header>No orders yet</:header>
                    <:subheader>
                      Your order history will appear here once you place an order.
                    </:subheader>
                  </.empty_state>
                </div>
                <.order_card :for={{dom_id, order} <- @streams.orders} id={dom_id} order={order} />
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :order, Order, required: true

  defp order_card(%{order: order} = assigns) do
    assigns =
      assigns
      |> assign(:formatted_date, DateHelpers.format_date(order.inserted_at))
      |> assign(:iso_date, DateHelpers.format_iso_date(order.inserted_at))
      |> assign(:formatted_price, order.total_price)

    ~H"""
    <div
      id={@id}
      class="border-t border-b border-gray-200 bg-white shadow-xs sm:rounded-lg sm:border"
    >
      <h3 class="sr-only">
        Order placed on <time datetime={@iso_date}>{@formatted_date}</time>
      </h3>

      <div class="flex items-center border-b border-gray-200 p-4 sm:grid sm:grid-cols-4 sm:gap-x-6 sm:p-6">
        <dl class="grid flex-1 grid-cols-2 gap-x-6 text-sm sm:col-span-3 sm:grid-cols-3 lg:col-span-2">
          <div>
            <dt class="font-medium text-gray-900">Order number</dt>
            <dd class="mt-1 text-gray-500">{@order.number}</dd>
          </div>
          <div class="hidden sm:block">
            <dt class="font-medium text-gray-900">Date placed</dt>
            <dd class="mt-1 text-gray-500">
              <time datetime={@iso_date}>{@formatted_date}</time>
            </dd>
          </div>
          <div>
            <dt class="font-medium text-gray-900">Total amount</dt>
            <dd class="mt-1 font-medium text-gray-900">{@formatted_price}</dd>
          </div>
        </dl>

        <div class="flex justify-end lg:hidden">
          <.dropdown id={"order-menu-#{@order.id}"} aria-label={"Options for order #{@order.number}"}>
            <:item href="#">View</:item>
            <:item href="#">Invoice</:item>
          </.dropdown>
        </div>

        <div class="hidden lg:col-span-2 lg:flex lg:items-center lg:justify-end lg:space-x-4">
          <a
            href="#"
            class="flex items-center justify-center rounded-md border border-gray-300 bg-white px-2.5 py-2 text-sm font-medium text-gray-700 shadow-xs hover:bg-gray-50 focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 focus:outline-hidden"
          >
            <span>View Order</span>
            <span class="sr-only">{@order.number}</span>
          </a>
          <a
            href="#"
            class="flex items-center justify-center rounded-md border border-gray-300 bg-white px-2.5 py-2 text-sm font-medium text-gray-700 shadow-xs hover:bg-gray-50 focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 focus:outline-hidden"
          >
            <span>View Invoice</span>
            <span class="sr-only">for order {@order.number}</span>
          </a>
        </div>
      </div>

      <h4 class="sr-only">Items</h4>
      <ul role="list" class="divide-y divide-gray-200">
        <.order_line_item :for={item <- @order.items} item={item} order={@order} />
      </ul>
    </div>
    """
  end

  attr :item, OrderItem, required: true
  attr :order, Order, required: true

  defp order_line_item(%{item: item} = assigns) do
    assigns =
      assigns
      |> assign(:variant_description, Variant.description(item.variant))
      |> assign(:formatted_price, Money.mult!(assigns.item.price, assigns.item.quantity))
      |> assign(:product_path, "/products/#{assigns.item.variant.product.slug}")

    ~H"""
    <li class="p-4 sm:p-6">
      <div class="flex items-center sm:items-start">
        <div class="size-20 shrink-0 overflow-hidden rounded-lg bg-gray-200 sm:size-40">
          <CartComponents.variant_image
            variant={@item.variant}
            width={400}
            height={400}
            class="size-full object-cover"
          />
        </div>
        <div class="ml-6 flex-1 text-sm">
          <div class="font-medium text-gray-900 sm:flex sm:justify-between">
            <h5>{@item.variant.product.name}</h5>
            <p class="mt-2 sm:mt-0">{@formatted_price}</p>
          </div>
          <p :if={@variant_description} class="hidden text-gray-500 sm:mt-2 sm:block">
            {@variant_description}
          </p>
        </div>
      </div>

      <div class="mt-6 sm:flex sm:justify-between">
        <.order_status status={@order.status} />

        <div class="mt-6 flex items-center divide-x divide-gray-200 border-t border-gray-200 pt-4 text-sm font-medium sm:mt-0 sm:ml-4 sm:border-none sm:pt-0">
          <div class="flex flex-1 justify-center pr-4">
            <.link
              navigate={@product_path}
              class="whitespace-nowrap text-indigo-600 hover:text-indigo-500"
            >
              View product
            </.link>
          </div>
          <div class="flex flex-1 justify-center pl-4">
            <.link
              navigate={@product_path}
              class="whitespace-nowrap text-indigo-600 hover:text-indigo-500"
            >
              Buy again
            </.link>
          </div>
        </div>
      </div>
    </li>
    """
  end

  attr :status, :atom, required: true

  defp order_status(assigns) do
    ~H"""
    <div class="flex items-center">
      <%= case @status do %>
        <% :delivered -> %>
          <.icon name="hero-check-circle-solid" class="size-5 text-green-500" />
          <p class="ml-2 text-sm font-medium text-gray-500">Delivered</p>
        <% :shipped -> %>
          <.icon name="hero-check-circle-solid" class="size-5 text-blue-500" />
          <p class="ml-2 text-sm font-medium text-gray-500">Shipped</p>
        <% :canceled -> %>
          <.icon name="hero-x-circle-solid" class="size-5 text-red-500" />
          <p class="ml-2 text-sm font-medium text-gray-500">Canceled</p>
        <% _ -> %>
          <.icon name="hero-clock-solid" class="size-5 text-yellow-500" />
          <p class="ml-2 text-sm font-medium text-gray-500">
            {Phoenix.Naming.humanize(@status)}
          </p>
      <% end %>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    orders = Orders.list_orders(socket.assigns.current_scope)

    {:ok, stream(socket, :orders, orders)}
  end
end
