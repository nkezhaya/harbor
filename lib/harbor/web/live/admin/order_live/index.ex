defmodule Harbor.Web.Admin.OrderLive.Index do
  use Harbor.Web, :live_view

  alias Harbor.Orders
  alias Harbor.Util

  @statuses ~w(pending paid shipped delivered canceled)

  @impl true
  def render(assigns) do
    ~H"""
    <AdminLayouts.app
      flash={@flash}
      current_scope={@current_scope}
      page_title={@page_title}
      current_path={@current_path}
      socket={@socket}
    >
      <.header :if={not (@orders_empty? and is_nil(@status_filter))}>
        Listing Orders
        <:actions>
          <.button variant="primary" navigate={admin_path(@socket, "/orders/new")}>
            <.icon name="hero-plus" /> New Order
          </.button>
        </:actions>
      </.header>

      <div :if={@orders_empty? and is_nil(@status_filter)} class="mt-8">
        <.empty_state
          icon="hero-clipboard-document-list"
          action_label="New Order"
          navigate={admin_path(@socket, "/orders/new")}
        >
          <:header>No orders</:header>
          <:subheader>Get started by creating your first order.</:subheader>
        </.empty_state>
      </div>

      <div :if={not (@orders_empty? and is_nil(@status_filter))}>
        <nav class="mt-6 mb-6 flex gap-x-2 flex-wrap">
          <.link
            navigate={admin_path(@socket, "/orders")}
            class={tab_classes(is_nil(@status_filter))}
          >
            All
          </.link>
          <.link
            :for={status <- @statuses}
            navigate={admin_path(@socket, "/orders?status=#{status}")}
            class={tab_classes(@status_filter == status)}
          >
            {Phoenix.Naming.humanize(status)}
          </.link>
        </nav>

        <.table
          :if={not @orders_empty?}
          id="orders"
          rows={@streams.orders}
          row_click={fn {_id, order} -> JS.navigate(admin_path(@socket, "/orders/#{order.id}")) end}
        >
          <:col :let={{_id, order}} label="Order">{order.number}</:col>
          <:col :let={{_id, order}} label="Email">{order.email}</:col>
          <:col :let={{_id, order}} label="Status">
            <span class={status_badge_classes(order.status)}>
              {Phoenix.Naming.humanize(order.status)}
            </span>
          </:col>
          <:col :let={{_id, order}} label="Total">{Util.formatted_price(order.total_price)}</:col>
          <:col :let={{_id, order}} label="Date">
            {DateHelpers.format_date(order.inserted_at)}
          </:col>
        </.table>

        <p :if={@orders_empty?} class="mt-6 text-sm text-gray-500 dark:text-gray-400">
          No orders match this filter.
        </p>
      </div>
    </AdminLayouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :statuses, @statuses)}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    status_filter = params["status"]
    orders = Orders.list_orders(socket.assigns.current_scope, params)

    {:noreply,
     socket
     |> assign(:page_title, "Listing Orders")
     |> assign(:status_filter, status_filter)
     |> assign(:orders_empty?, orders == [])
     |> stream(:orders, orders, reset: true)}
  end

  defp tab_classes(true) do
    "rounded-md px-3 py-2 text-sm font-medium bg-indigo-100 text-indigo-700 dark:bg-indigo-500/20 dark:text-indigo-300"
  end

  defp tab_classes(false) do
    "rounded-md px-3 py-2 text-sm font-medium text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
  end

  defp status_badge_classes(status) do
    base = "inline-flex items-center rounded-full px-2 py-1 text-xs font-medium"

    color =
      case status do
        :pending -> "bg-yellow-100 text-yellow-800 dark:bg-yellow-500/20 dark:text-yellow-300"
        :paid -> "bg-green-100 text-green-800 dark:bg-green-500/20 dark:text-green-300"
        :shipped -> "bg-blue-100 text-blue-800 dark:bg-blue-500/20 dark:text-blue-300"
        :delivered -> "bg-gray-100 text-gray-800 dark:bg-gray-500/20 dark:text-gray-300"
        :canceled -> "bg-red-100 text-red-800 dark:bg-red-500/20 dark:text-red-300"
        _ -> "bg-gray-100 text-gray-600 dark:bg-gray-500/20 dark:text-gray-400"
      end

    "#{base} #{color}"
  end
end
