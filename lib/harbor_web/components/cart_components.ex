defmodule HarborWeb.CartComponents do
  @moduledoc """
  Component helpers that render the cart toggle popover and related UI.

  The module exposes a `cart_popover/1` function component that renders a
  button with an accessible item count notification and an expandable popover
  that lists the current [CartItem](`Harbor.Checkout.CartItem`) entries.
  """
  use HarborWeb, :component

  alias Harbor.Catalog.Variant
  alias Harbor.{Checkout, Util}
  alias Harbor.Checkout.{Cart, CartItem}
  alias HarborWeb.ImageHelpers

  @doc """
  Renders the variant's primary image or a placeholder when no image is
  available. The `width` and `height` attributes control the dimensions passed
  to the generated image URL.

  ## Examples

      <CartComponents.variant_image variant={variant} />
  """
  attr :variant, Variant, required: true
  attr :width, :integer, default: 96
  attr :height, :integer, default: 96
  attr :class, :string, default: "size-16"

  def variant_image(%{variant: variant} = assigns) do
    assigns = assign(assigns, :image, Variant.main_image(variant))

    ~H"""
    <%= if @image do %>
      <img
        src={ImageHelpers.product_image_url(@image, width: @width, height: @height)}
        alt={@image.alt_text}
        class={["flex-none rounded-md border border-gray-200 object-cover", @class]}
      />
    <% else %>
      <div class={[
        "flex flex-none items-center justify-center rounded-md border border-dashed border-gray-200 bg-gray-50 text-xs text-gray-400",
        @class
      ]}>
        No image
      </div>
    <% end %>
    """
  end

  @doc """
  Displays a summarized cost breakdown for the provided cart.

  ## Examples

      <CartComponents.order_summary cart={cart} />
  """
  attr :cart, Cart, required: true
  attr :class, :string, default: nil

  def order_summary(assigns) do
    assigns =
      assigns
      |> assign(:class, ["rounded-lg bg-gray-50", assigns.class])
      |> assign(:summary, summary_for(assigns.cart))

    ~H"""
    <section aria-labelledby="summary-heading" class={@class}>
      <h2 id="summary-heading" class="text-lg font-medium text-gray-900">
        Order summary
      </h2>

      <dl class="mt-6 space-y-4">
        <div class="flex items-center justify-between">
          <dt class="text-sm text-gray-600">Subtotal</dt>
          <dd class="text-sm font-medium text-gray-900">
            {Util.formatted_price(@summary.subtotal)}
          </dd>
        </div>

        <div class="flex items-center justify-between border-t border-gray-200 pt-4">
          <dt class="flex items-center gap-2 text-sm text-gray-600">
            <span>Shipping estimate</span>
            <a href="#" class="text-gray-400 transition hover:text-gray-500">
              <span class="sr-only">Learn more about how shipping is calculated</span>
              <.icon name="hero-question-mark-circle" class="size-5" />
            </a>
          </dt>
          <dd class="text-sm font-medium text-gray-900">
            Calculated at checkout
          </dd>
        </div>

        <div class="flex items-center justify-between border-t border-gray-200 pt-4">
          <dt class="flex items-center gap-2 text-sm text-gray-600">
            <span>Tax estimate</span>
            <a href="#" class="text-gray-400 transition hover:text-gray-500">
              <span class="sr-only">Learn more about how tax is calculated</span>
              <.icon name="hero-question-mark-circle" class="size-5" />
            </a>
          </dt>
          <dd class="text-sm font-medium text-gray-900">
            Calculated at checkout
          </dd>
        </div>

        <div class="flex items-center justify-between border-t border-gray-200 pt-4">
          <dt class="text-base font-medium text-gray-900">Order total</dt>
          <dd class="text-base font-medium text-gray-900">
            {Util.formatted_price(@summary.total)}
          </dd>
        </div>
      </dl>

      <div class="mt-6">
        <%= if @summary.item_count > 0 do %>
          <.link
            navigate={~p"/checkout"}
            class="block w-full rounded-md border border-transparent bg-indigo-600 px-4 py-3 text-center text-base font-medium text-white shadow-xs transition hover:bg-indigo-700 focus:outline-hidden focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 focus:ring-offset-gray-50"
          >
            Checkout
          </.link>
        <% else %>
          <.button
            type="button"
            variant="primary"
            size="custom"
            class="w-full px-4 py-3 text-base"
            disabled
          >
            Checkout
          </.button>
        <% end %>
      </div>
    </section>
    """
  end

  @doc """
  Renders the cart popover for the given scope.
  """
  attr :current_scope, Harbor.Accounts.Scope,
    required: true,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :cart, Harbor.Checkout.Cart, default: nil

  def cart_popover(%{cart: cart} = assigns) do
    count =
      if is_nil(cart) do
        []
      else
        cart.items
      end
      |> Enum.reduce(0, fn %CartItem{quantity: quantity}, acc ->
        acc + quantity
      end)

    assigns = assign(assigns, :cart_item_count, count)

    ~H"""
    <div class="relative">
      <button
        id="cart-toggle"
        type="button"
        class="group -m-2 flex items-center rounded-full p-2 text-gray-500 transition hover:text-gray-900 focus:outline-none focus:ring-2 focus:ring-indigo-500 cursor-pointer"
        aria-haspopup="dialog"
        aria-expanded="false"
        phx-click={toggle_cart_popover()}
      >
        <.icon name="hero-shopping-bag" class="h-6 w-6" />
        <span class="ml-2 text-sm font-medium text-gray-700 group-hover:text-gray-800">
          {@cart_item_count}
        </span>
        <span class="sr-only">
          <%= case @cart_item_count do %>
            <% 0 -> %>
              Cart is empty
            <% _ -> %>
              {ngettext("%{count} item in cart", "%{count} items in cart", @cart_item_count,
                count: @cart_item_count
              )}
          <% end %>
        </span>
      </button>

      <div
        id="cart-popover"
        class="absolute right-0 top-full z-50 mt-3 hidden w-80 rounded-lg border border-gray-200 bg-white p-6 text-sm shadow-xl focus:outline-none lg:-mr-1.5"
        role="dialog"
        aria-modal="true"
        aria-labelledby="cart-popover-title"
        phx-click-away={hide_cart_popover()}
        phx-window-keydown={hide_cart_popover()}
        phx-key="escape"
      >
        <h2 id="cart-popover-title" class="sr-only">Shopping Cart</h2>

        <%= if @cart_item_count > 0 do %>
          <ul role="list" class="divide-y divide-gray-200">
            <.cart_item
              :for={item <- @cart.items}
              :key={item.id}
              id={"cart-item-#{item.id}"}
              cart_item={item}
            />
          </ul>

          <div class="mt-6">
            <.link
              navigate={~p"/checkout"}
              class="block w-full rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-center text-sm font-medium text-white shadow-xs hover:bg-indigo-700 focus:outline-hidden focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 focus:ring-offset-gray-50"
            >
              Checkout
            </.link>

            <p class="mt-6 text-center">
              <.link
                navigate={~p"/cart"}
                class="text-sm font-medium text-indigo-600 hover:text-indigo-500"
              >
                View Shopping Bag
              </.link>
            </p>
          </div>
        <% else %>
          <p class="text-sm text-gray-500">
            Your cart is empty.
          </p>
        <% end %>
      </div>
    </div>
    """
  end

  defp cart_item(%{cart_item: %{variant: variant}} = assigns) do
    assigns = assign(assigns, :variant_description, Variant.description(variant))

    ~H"""
    <li id={"cart-item-#{@cart_item.id}"} class="flex gap-4 py-4">
      <.variant_image variant={@cart_item.variant} />

      <div class="flex-auto">
        <h3 class="font-medium text-gray-900">
          <.link
            navigate={~p"/products/#{@cart_item.variant.product.slug}"}
            class="hover:text-indigo-600 hover:underline"
          >
            {@cart_item.variant.product.name}
          </.link>
        </h3>
        <p :if={@variant_description} class="mt-1 text-sm text-gray-500">
          {@variant_description}
        </p>
      </div>
    </li>
    """
  end

  defp summary_for(cart) do
    items = items_from_cart(cart)

    subtotal =
      Enum.reduce(items, 0, fn %CartItem{variant: variant, quantity: quantity}, acc ->
        acc + variant.price * quantity
      end)

    item_count =
      Enum.reduce(items, 0, fn %CartItem{quantity: quantity}, acc -> acc + quantity end)

    %{
      subtotal: subtotal,
      shipping_estimate: nil,
      tax_estimate: nil,
      total: subtotal,
      item_count: item_count
    }
  end

  defp items_from_cart(%Cart{items: items}) when is_list(items), do: items
  defp items_from_cart(_), do: []

  defp toggle_cart_popover(js \\ %JS{}) do
    js
    |> JS.toggle(
      to: "#cart-popover",
      in: {"ease-out duration-200", "opacity-0 -translate-y-2", "opacity-100 translate-y-0"},
      out: {"ease-in duration-150", "opacity-100 translate-y-0", "opacity-0 -translate-y-2"}
    )
    |> JS.toggle_attribute({"aria-expanded", "true", "false"}, to: "#cart-toggle")
  end

  defp hide_cart_popover(js \\ %JS{}) do
    js
    |> JS.hide(
      to: "#cart-popover",
      transition:
        {"ease-in duration-150", "opacity-100 translate-y-0", "opacity-0 -translate-y-2"}
    )
    |> JS.set_attribute({"aria-expanded", "false"}, to: "#cart-toggle")
  end

  @doc """
  Handles LiveView hook events to add a variant to the cart and broadcast the
  updated cart state.
  """
  def hooked_event("add_to_cart", params, socket) do
    Checkout.add_item_to_cart(socket.assigns.current_scope, params)

    {:halt, socket}
  end

  def hooked_event(_event, _params, socket) do
    {:cont, socket}
  end
end
