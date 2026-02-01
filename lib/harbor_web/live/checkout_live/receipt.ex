defmodule HarborWeb.CheckoutLive.Receipt do
  @moduledoc """
  Receipt page for completed checkout sessions.
  """
  use HarborWeb, :live_view

  alias Harbor.Catalog.Variant
  alias Harbor.Checkout
  alias Harbor.Util

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      root_categories={@root_categories}
      cart={@cart}
    >
      <div class="bg-white">
        <div class="mx-auto max-w-6xl px-4 py-12 sm:px-6 lg:px-8">
          <div class="flex flex-col gap-10 lg:flex-row lg:items-start">
            <section
              id="checkout-receipt"
              class="flex-1"
              aria-labelledby="receipt-heading"
            >
              <div class="rounded-xl border border-gray-200 bg-gray-50 p-6 shadow-sm">
                <h1 id="receipt-heading" class="text-2xl font-semibold text-gray-900">
                  Thanks for your order
                </h1>

                <p class="mt-2 text-sm text-gray-600">
                  We received your order and will start processing it now.
                  <span :if={@order.email} class="block text-gray-700">
                    We'll send updates to <span class="font-medium text-gray-900">{@order.email}</span>.
                  </span>
                </p>

                <dl class="mt-6 grid grid-cols-1 gap-4 sm:grid-cols-2">
                  <div class="rounded-lg bg-white p-4">
                    <dt class="text-xs font-medium text-gray-500">Order number</dt>
                    <dd
                      id="receipt-order-number"
                      class="mt-1 text-sm font-semibold text-gray-900"
                    >
                      {@order.number}
                    </dd>
                  </div>
                  <div class="rounded-lg bg-white p-4">
                    <dt class="text-xs font-medium text-gray-500">Status</dt>
                    <dd
                      id="receipt-order-status"
                      class="mt-1 text-sm font-semibold text-gray-900"
                    >
                      {Phoenix.Naming.humanize(@order.status)}
                    </dd>
                  </div>
                  <div class="rounded-lg bg-white p-4">
                    <dt class="text-xs font-medium text-gray-500">Delivery</dt>
                    <dd
                      id="receipt-delivery-method"
                      class="mt-1 text-sm font-semibold text-gray-900"
                    >
                      {@order.delivery_method_name || "No delivery method"}
                    </dd>
                  </div>
                  <div class="rounded-lg bg-white p-4">
                    <dt class="text-xs font-medium text-gray-500">Total</dt>
                    <dd
                      id="receipt-total"
                      class="mt-1 text-sm font-semibold text-gray-900"
                    >
                      {Util.formatted_price(@pricing.total_price)}
                    </dd>
                  </div>
                </dl>
              </div>

              <div class="mt-8 space-y-8">
                <section aria-labelledby="items-heading">
                  <h2 id="items-heading" class="text-lg font-semibold text-gray-900">
                    Items
                  </h2>

                  <div
                    id="receipt-items"
                    class="mt-4 divide-y divide-gray-200 rounded-lg border border-gray-200"
                  >
                    <div
                      :for={item <- @order.items}
                      id={"receipt-item-#{item.id}"}
                      class="flex items-start justify-between gap-6 px-4 py-5"
                    >
                      <div class="min-w-0">
                        <p class="text-sm font-medium text-gray-900">
                          {item.variant.product.name}
                        </p>
                        <%= if description = Variant.description(item.variant) do %>
                          <p class="mt-1 text-sm text-gray-500">{description}</p>
                        <% end %>
                        <p class="mt-1 text-sm text-gray-500">Qty: {item.quantity}</p>
                      </div>
                      <p class="text-sm font-medium text-gray-900">
                        {Util.formatted_price(item.price * item.quantity)}
                      </p>
                    </div>
                  </div>
                </section>

                <section aria-labelledby="shipping-heading">
                  <h2 id="shipping-heading" class="text-lg font-semibold text-gray-900">
                    Shipping address
                  </h2>
                  <div
                    id="receipt-shipping-address"
                    class="mt-3 rounded-lg border border-gray-200 p-4 text-sm text-gray-700"
                  >
                    <%= if @order.shipping_address do %>
                      <CheckoutComponents.address_summary address={@order.shipping_address} />
                    <% else %>
                      <span>No shipping required.</span>
                    <% end %>
                  </div>
                </section>

                <section aria-labelledby="receipt-order-heading" class="lg:hidden">
                  <h2 id="receipt-order-heading" class="text-lg font-semibold text-gray-900">
                    Order summary
                  </h2>
                  <dl class="mt-3 space-y-3 text-sm">
                    <div class="flex items-center justify-between">
                      <dt class="text-gray-600">Subtotal</dt>
                      <dd class="font-medium text-gray-900">
                        {Util.formatted_price(@pricing.subtotal)}
                      </dd>
                    </div>
                    <div class="flex items-center justify-between">
                      <dt class="text-gray-600">Taxes</dt>
                      <dd class="font-medium text-gray-900">
                        {Util.formatted_price(@pricing.tax)}
                      </dd>
                    </div>
                    <div class="flex items-center justify-between">
                      <dt class="text-gray-600">Shipping</dt>
                      <dd class="font-medium text-gray-900">
                        {Util.formatted_price(@pricing.shipping_price)}
                      </dd>
                    </div>
                    <div class="flex items-center justify-between border-t border-gray-200 pt-3">
                      <dt class="font-semibold text-gray-900">Total</dt>
                      <dd class="font-semibold text-gray-900">
                        {Util.formatted_price(@pricing.total_price)}
                      </dd>
                    </div>
                  </dl>
                </section>
              </div>
            </section>

            <CheckoutComponents.order_summary order={@order} pricing={@pricing} />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, %{assigns: %{current_scope: current_scope}} = socket) do
    case Checkout.get_completed_session(current_scope, id) do
      {:ok, session} ->
        pricing = Checkout.build_pricing(session.order)

        {:ok,
         socket
         |> assign(:session, session)
         |> assign(:order, session.order)
         |> assign(:pricing, pricing)
         |> assign(:current_scope, current_scope)}

      _error ->
        {:ok,
         socket
         |> put_flash(:error, "Checkout session not found.")
         |> push_navigate(to: ~p"/cart")}
    end
  end
end
