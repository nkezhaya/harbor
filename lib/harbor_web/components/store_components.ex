defmodule HarborWeb.StoreComponents do
  @moduledoc """
  Storefront product components.
  """
  use HarborWeb, :component

  alias Harbor.Catalog.Product
  alias Harbor.{Checkout, Util}
  alias Harbor.Checkout.{Cart, CartItem}
  alias HarborWeb.ImageHelpers

  @doc """
  Renders a product card that would appear in the PLP grid.
  """
  attr :product, Product, required: true

  def product_card(assigns) do
    ~H"""
    <a href={~p"/products/#{@product.slug}"} class="group">
      <.product_image product={@product} />

      <h3 class="mt-4 text-sm text-gray-700">{@product.name}</h3>

      <p class="mt-1 text-lg font-medium text-gray-900">
        <%= if @product.default_variant do %>
          {Util.formatted_price(@product.default_variant.price)}
        <% end %>
      </p>
    </a>
    """
  end

  @doc """
  Renders the main product image for a given product. If one doesn't exist, it
  renders a placeholder.
  """
  attr :product, Product, required: true

  def product_image(%{product: product} = assigns) do
    image = List.first(product.images)

    class =
      "aspect-square w-full rounded-lg bg-gray-200 object-cover group-hover:opacity-75 xl:aspect-7/8"

    assigns = assign(assigns, image: image, class: class)

    ~H"""
    <%= if @image do %>
      <img src={ImageHelpers.product_image_url(@image)} alt={@image.alt_text} class={@class} />
    <% else %>
      <div class={@class}></div>
    <% end %>
    """
  end

  @doc """
  Renders the cart popover for the given scope.
  """
  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  def cart_popover(assigns) do
    assigns =
      assigns
      |> assign_cart()
      |> assign_cart_item_count()

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
        <span class="sr-only">{cart_item_sr_label(@cart_item_count)}</span>
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

        <p :if={@cart_item_count == 0} class="text-sm text-gray-500">
          Your cart is empty.
        </p>

        <ul :if={@cart_item_count > 0} role="list" class="divide-y divide-gray-200">
          <li
            :for={item <- cart_items(@cart)}
            id={"cart-item-#{item.id}"}
            class="flex gap-4 py-4"
          >
            <.variant_thumbnail variant={item.variant} />

            <div class="flex-auto">
              <h3 class="font-medium text-gray-900">
                <.link
                  navigate={~p"/products/#{item.variant.product.slug}"}
                  class="hover:text-indigo-600 hover:underline"
                >
                  {item.variant.product.name}
                </.link>
              </h3>
              <p :if={desc = variant_description(item)} class="mt-1 text-sm text-gray-500">
                {desc}
              </p>
            </div>
          </li>
        </ul>

        <div :if={@cart_item_count > 0} class="mt-6">
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
      </div>
    </div>
    """
  end

  defp variant_thumbnail(%{variant: variant} = assigns) do
    assigns = assign(assigns, :image, variant_image(variant))

    ~H"""
    <%= if @image do %>
      <img
        src={ImageHelpers.product_image_url(@image, width: 96, height: 96)}
        alt={@image.alt_text}
        class="h-16 w-16 flex-none rounded-md border border-gray-200 object-cover"
      />
    <% else %>
      <div class="flex h-16 w-16 flex-none items-center justify-center rounded-md border border-dashed border-gray-200 bg-gray-50 text-xs text-gray-400">
        No image
      </div>
    <% end %>
    """
  end

  defp assign_cart(assigns) do
    assign_new(assigns, :cart, fn %{current_scope: current_scope} ->
      if current_scope do
        Checkout.fetch_active_cart_with_items(current_scope)
      end
    end)
  end

  defp assign_cart_item_count(assigns) do
    count =
      assigns.cart
      |> cart_items()
      |> Enum.reduce(0, fn %CartItem{quantity: quantity}, acc -> acc + quantity end)

    assign(assigns, :cart_item_count, count)
  end

  defp cart_items(%Cart{items: items}) when is_list(items), do: items
  defp cart_items(_), do: []

  defp variant_image(%{product: %{images: [image | _]}}), do: image
  defp variant_image(_variant), do: nil

  defp variant_description(%CartItem{variant: %{option_values: option_values, sku: sku}})
       when is_list(option_values) do
    case Enum.map_join(option_values, ", ", & &1.name) do
      "" -> sku
      desc -> desc
    end
  end

  defp variant_description(_cart_item), do: nil

  defp cart_item_sr_label(0), do: "Cart is empty"
  defp cart_item_sr_label(1), do: "1 item in cart, view bag"

  defp cart_item_sr_label(count) when is_integer(count) and count > 1 do
    "#{count} items in cart, view bag"
  end

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
end
