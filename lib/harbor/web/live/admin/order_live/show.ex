defmodule Harbor.Web.Admin.OrderLive.Show do
  use Harbor.Web, :live_view

  alias Harbor.Orders

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
      <.header>
        Order {@order.number}
        <:subtitle>
          <span class={status_badge_classes(@order.status)}>
            {Phoenix.Naming.humanize(@order.status)}
          </span>
        </:subtitle>
        <:actions>
          <.button navigate={admin_path(@socket, "/orders")}>
            <.icon name="hero-arrow-left" />
          </.button>
          <.button
            variant="primary"
            navigate={admin_path(@socket, "/orders/#{@order.id}/edit?return_to=show")}
          >
            <.icon name="hero-pencil-square" /> Edit order
          </.button>
        </:actions>
      </.header>

      <div class="mt-6 flex flex-wrap gap-3">
        <.button
          :if={@order.status == :pending}
          variant="primary"
          phx-click="update_status"
          phx-value-status="paid"
          data-confirm="Mark this order as paid?"
        >
          Mark as Paid
        </.button>
        <.button
          :if={@order.status == :paid}
          variant="primary"
          phx-click="update_status"
          phx-value-status="shipped"
          data-confirm="Mark this order as shipped?"
        >
          Mark as Shipped
        </.button>
        <.button
          :if={@order.status == :shipped}
          variant="primary"
          phx-click="update_status"
          phx-value-status="delivered"
          data-confirm="Mark this order as delivered?"
        >
          Mark as Delivered
        </.button>
        <.button
          :if={@order.status in [:pending, :paid]}
          phx-click="update_status"
          phx-value-status="canceled"
          data-confirm="Are you sure you want to cancel this order?"
        >
          Cancel Order
        </.button>
      </div>

      <.list>
        <:item title="Order number">{@order.number}</:item>
        <:item title="Email">{@order.email}</:item>
        <:item title="Notes">{@order.notes}</:item>
        <:item title="Created">{DateHelpers.format_datetime(@order.inserted_at)}</:item>
        <:item title="Updated">{DateHelpers.format_datetime(@order.updated_at)}</:item>
      </.list>

      <div :if={@order.address_line1} class="mt-8">
        <h3 class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
          Shipping Address
        </h3>
        <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
          {@order.address_name}<br />
          {@order.address_line1}<br />
          <span :if={@order.address_line2}>{@order.address_line2}<br /></span>
          {@order.address_city}, {@order.address_region} {@order.address_postal_code}<br />
          {@order.address_country}
          <span :if={@order.address_phone}><br />{@order.address_phone}</span>
        </p>
      </div>

      <div class="mt-8">
        <h3 class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
          Financial Summary
        </h3>
        <.list>
          <:item title="Subtotal">{@order.subtotal}</:item>
          <:item title="Tax">{@order.tax}</:item>
          <:item title="Shipping">{@order.shipping_price}</:item>
          <:item title="Total">{@order.total_price}</:item>
        </.list>
      </div>

      <div :if={@order.items != []} class="mt-8">
        <h3 class="text-base font-semibold leading-7 text-gray-900 dark:text-gray-100">
          Order Items
        </h3>
        <.table id="order-items" rows={@order.items}>
          <:col :let={item} label="Product">
            {item.variant.product.name}
            <span :if={item.variant.sku} class="text-gray-500 dark:text-gray-400">
              ({item.variant.sku})
            </span>
          </:col>
          <:col :let={item} label="Quantity">{item.quantity}</:col>
          <:col :let={item} label="Unit price">{item.price}</:col>
          <:col :let={item} label="Line total">
            {Money.mult!(item.price, item.quantity)}
          </:col>
        </.table>
      </div>
    </AdminLayouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    order = Orders.get_order!(socket.assigns.current_scope, id)

    {:ok,
     socket
     |> assign(:page_title, "Order #{order.number}")
     |> assign(:order, order)}
  end

  @impl true
  def handle_event("update_status", %{"status" => status}, socket) do
    case Orders.update_order(
           socket.assigns.current_scope,
           socket.assigns.order,
           %{status: status}
         ) do
      {:ok, order} ->
        order = Orders.get_order!(socket.assigns.current_scope, order.id)

        {:noreply,
         socket
         |> put_flash(:info, "Order updated to #{status}")
         |> assign(:order, order)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update order status")}
    end
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
