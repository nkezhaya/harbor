defmodule Harbor.Web.CheckoutLive.Receipt do
  @moduledoc """
  Receipt page for completed checkout sessions.
  """
  use Harbor.Web, :live_view

  alias Harbor.Catalog.Variant
  alias Harbor.{Checkout, Settings}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.receipt
      flash={@flash}
      class="px-4 pt-16 pb-24 sm:px-6 sm:pt-24 lg:px-8 lg:py-32"
    >
      <div id="checkout-receipt" class="mx-auto max-w-3xl">
        <div class="max-w-xl">
          <h1 class="text-base font-medium text-indigo-600">Thank you!</h1>
          <p id="receipt-heading" class="mt-2 text-4xl font-bold tracking-tight text-gray-900">
            We've received your order.
          </p>
          <p class="mt-2 text-base text-gray-500">
            We'll start processing it now.
            <span :if={@order.email} class="block">
              We'll send updates to <span class="font-medium text-gray-700">{@order.email}</span>.
            </span>
          </p>

          <dl class="mt-12 grid grid-cols-1 gap-6 text-sm font-medium sm:grid-cols-2">
            <div>
              <dt class="text-gray-900">Order number</dt>
              <dd id="receipt-order-number" class="mt-2 text-indigo-600">
                {@order.number}
              </dd>
            </div>
            <div>
              <dt class="text-gray-900">Status</dt>
              <dd id="receipt-order-status" class="mt-2 text-gray-700">
                {humanize(@order.status)}
              </dd>
            </div>
          </dl>
        </div>

        <section aria-labelledby="order-heading" class="mt-10 border-t border-gray-200">
          <h2 id="order-heading" class="sr-only">Your order</h2>

          <div id="receipt-items">
            <article
              :for={item <- @order.items}
              id={"receipt-item-#{item.id}"}
              class="flex space-x-6 border-b border-gray-200 py-10"
            >
              <CartComponents.variant_image
                variant={item.variant}
                width={160}
                height={160}
                class="size-20 bg-gray-100 sm:size-40"
              />
              <div class="flex flex-auto flex-col">
                <div>
                  <h3 class="font-medium text-gray-900">
                    {item.variant.product.name}
                  </h3>
                  <%= if description = Variant.description(item.variant) do %>
                    <p class="mt-2 text-sm text-gray-600">{description}</p>
                  <% end %>
                </div>
                <div class="mt-6 flex flex-1 items-end">
                  <dl class="flex divide-x divide-gray-200 text-sm">
                    <div class="flex pr-4 sm:pr-6">
                      <dt class="font-medium text-gray-900">Quantity</dt>
                      <dd class="ml-2 text-gray-700">{item.quantity}</dd>
                    </div>
                    <div class="flex pl-4 sm:pl-6">
                      <dt class="font-medium text-gray-900">Price</dt>
                      <dd class="ml-2 text-gray-700">
                        {Money.mult!(item.price, item.quantity)}
                      </dd>
                    </div>
                  </dl>
                </div>
              </div>
            </article>
          </div>

          <div class="sm:ml-40 sm:pl-6">
            <section
              :if={@order.shipping_address}
              aria-labelledby="shipping-address-heading"
              class="py-10"
            >
              <h3 id="shipping-address-heading" class="sr-only">Address</h3>
              <dl class="text-sm">
                <div>
                  <dt class="font-medium text-gray-900">Shipping address</dt>
                  <dd id="receipt-shipping-address" class="mt-2 text-gray-700">
                    <address class="not-italic">
                      <CheckoutComponents.address_summary address={@order.shipping_address} />
                    </address>
                  </dd>
                </div>
              </dl>
            </section>

            <section
              :if={@settings.delivery_enabled}
              aria-labelledby="delivery-heading"
              class="border-t border-gray-200 py-10"
            >
              <h3 id="delivery-heading" class="sr-only">Delivery</h3>
              <dl class="text-sm">
                <div>
                  <dt class="font-medium text-gray-900">Delivery method</dt>
                  <dd id="receipt-delivery-method" class="mt-2 text-gray-700">
                    {@order.delivery_method_name || "No delivery method"}
                  </dd>
                </div>
              </dl>
            </section>

            <section aria-labelledby="summary-heading" class="border-t border-gray-200 pt-10">
              <h3 id="summary-heading" class="sr-only">Summary</h3>
              <dl class="space-y-6 text-sm">
                <div class="flex justify-between">
                  <dt class="font-medium text-gray-900">Subtotal</dt>
                  <dd class="text-gray-700">{@pricing.subtotal}</dd>
                </div>
                <div
                  :if={@settings.tax_enabled}
                  id="receipt-summary-tax"
                  class="flex justify-between"
                >
                  <dt class="font-medium text-gray-900">Taxes</dt>
                  <dd class="text-gray-700">{@pricing.tax || Money.zero(:USD)}</dd>
                </div>
                <div
                  :if={@settings.delivery_enabled}
                  id="receipt-summary-shipping"
                  class="flex justify-between"
                >
                  <dt class="font-medium text-gray-900">Shipping</dt>
                  <dd class="text-gray-700">{@pricing.shipping_price}</dd>
                </div>
                <div class="flex justify-between border-t border-gray-200 pt-6">
                  <dt class="font-medium text-gray-900">Total</dt>
                  <dd id="receipt-total" class="font-medium text-gray-900">
                    {@pricing.total_price}
                  </dd>
                </div>
              </dl>
            </section>
          </div>
        </section>
      </div>
    </Layouts.receipt>
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
         |> assign(:settings, Settings.get())
         |> assign(:current_scope, current_scope)}

      _error ->
        {:ok,
         socket
         |> put_flash(:error, "Checkout session not found.")
         |> push_navigate(to: "/cart")}
    end
  end
end
