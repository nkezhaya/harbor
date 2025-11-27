defmodule HarborWeb.CheckoutComponents do
  @moduledoc """
  Function components that support the checkout experience.

  These components power the desktop order summary and individual cart item
  rows. Each component expects preloaded data so that templates can render
  without issuing additional database queries.
  """

  use HarborWeb, :component
  import Harbor.Util, only: [formatted_price: 1]

  alias Harbor.Catalog.Variant
  alias Harbor.Checkout.{Cart, CartItem, Pricing}
  alias HarborWeb.CartComponents

  @doc """
  Renders the desktop order summary sidebar for a checkout session.

  Expects a [Cart](`Harbor.Checkout.Cart`) with items and a
  [Pricing](`Harbor.Checkout.Pricing`) summary so that totals can be displayed
  alongside product details.
  """
  attr :cart, Cart, required: true
  attr :pricing, Pricing, required: true

  def order_summary(assigns) do
    ~H"""
    <section
      aria-labelledby="summary-heading"
      class="hidden w-full max-w-md flex-col bg-gray-50 lg:flex"
    >
      <h2 id="summary-heading" class="sr-only">Order summary</h2>

      <ul role="list" class="flex-auto divide-y divide-gray-200 overflow-y-auto px-6">
        <.cart_item :for={item <- @cart.items} item={item} class="flex space-x-6 py-6" />
      </ul>

      <div class="sticky bottom-0 flex-none border-t border-gray-200 bg-gray-50 p-6">
        <dl class="space-y-6 text-sm font-medium text-gray-500">
          <div class="flex justify-between">
            <dt>Subtotal</dt>
            <dd class="text-gray-900">{formatted_price(@pricing.subtotal)}</dd>
          </div>
          <div class="flex justify-between">
            <dt>Taxes</dt>
            <dd class="text-gray-900">{formatted_price(@pricing.tax)}</dd>
          </div>
          <div class="flex justify-between">
            <dt>Shipping</dt>
            <dd class="text-gray-900">{formatted_price(@pricing.shipping_price)}</dd>
          </div>
          <div class="flex items-center justify-between border-t border-gray-200 pt-6 text-gray-900">
            <dt>Total</dt>
            <dd class="text-base">{formatted_price(@pricing.total_price)}</dd>
          </div>
        </dl>
      </div>
    </section>
    """
  end

  @doc """
  Renders a single cart item within the order summary list.

  The component relies on the associated variant and product data being
  preloaded so image, description, and pricing details render without extra
  queries. An optional `:class` attribute can be provided to tweak layout
  styling from the call site.
  """
  attr :item, CartItem, required: true
  attr :class, :string

  def cart_item(assigns) do
    ~H"""
    <li class={@class}>
      <CartComponents.variant_image
        variant={@item.variant}
        width={160}
        height={160}
        class="size-40 bg-gray-200"
      />
      <div class="flex flex-col justify-between space-y-4">
        <div class="space-y-1 text-sm font-medium">
          <h3 class="text-gray-900">{@item.variant.product.name}</h3>
          <p class="text-gray-900">{formatted_price(@item.variant.price * @item.quantity)}</p>
          <p class="text-gray-500">{Variant.description(@item.variant)}</p>
          <p class="text-gray-500">Qty: {@item.quantity}</p>
        </div>
        <div class="flex space-x-4">
          <button
            type="button"
            class="text-sm font-medium text-indigo-600 hover:text-indigo-500"
          >
            Edit
          </button>
          <div class="flex border-l border-gray-300 pl-4">
            <button
              type="button"
              class="text-sm font-medium text-indigo-600 hover:text-indigo-500"
            >
              Remove
            </button>
          </div>
        </div>
      </div>
    </li>
    """
  end
end
