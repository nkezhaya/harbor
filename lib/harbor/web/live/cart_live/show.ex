defmodule Harbor.Web.CartLive.Show do
  @moduledoc """
  Storefront cart page that lets shoppers review and adjust their order.
  """
  use Harbor.Web, :live_view

  alias Harbor.Catalog.Variant
  alias Harbor.{Checkout, Util}
  alias Harbor.Checkout.{Cart, CartItem}

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
        <div class="mx-auto max-w-2xl px-4 pt-16 pb-24 sm:px-6 lg:max-w-7xl lg:px-8">
          <%= if @empty_cart? do %>
            <div class="mt-16 flex flex-col items-center gap-6 text-center">
              <div class="rounded-full bg-gray-100 p-4 text-gray-400">
                <.icon name="hero-shopping-bag" class="size-8" />
              </div>

              <div class="space-y-2">
                <p class="text-lg font-medium text-gray-900">Your cart is empty</p>
                <p class="text-sm text-gray-600">
                  Browse the catalogue to discover something new.
                </p>
              </div>

              <.link
                navigate="/products"
                class="inline-flex items-center gap-2 rounded-md border border-transparent bg-indigo-600 px-4 py-3 text-sm font-medium text-white shadow-xs transition hover:bg-indigo-700 focus:outline-hidden focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 focus:ring-offset-white"
              >
                Continue shopping
              </.link>
            </div>
          <% else %>
            <h1 class="text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">
              Shopping Cart
            </h1>
            <div class="mt-12 lg:grid lg:grid-cols-12 lg:items-start lg:gap-x-12 xl:gap-x-16">
              <section aria-labelledby="cart-heading" class="lg:col-span-7">
                <h2 id="cart-heading" class="sr-only">Items in your shopping cart</h2>

                <ul
                  id="cart-items"
                  role="list"
                  class="divide-y divide-gray-200 border-t border-b border-gray-200"
                  phx-update="stream"
                >
                  <.cart_line_item
                    :for={{dom_id, cart_item} <- @streams.cart_items}
                    id={dom_id}
                    cart_item={cart_item}
                  />
                </ul>
              </section>

              <CartComponents.order_summary
                cart={@cart}
                class="mt-16 px-4 py-6 sm:p-6 lg:col-span-5 lg:mt-0 lg:p-8"
              />
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  attr :cart_item, CartItem, required: true

  defp cart_line_item(%{cart_item: %{variant: variant}} = assigns) do
    assigns =
      assigns
      |> assign(:variant, variant)
      |> assign(:variant_description, Variant.description(variant))
      |> assign(:price, Util.formatted_price(variant.price))
      |> assign(:form, to_form(CartItem.changeset(assigns.cart_item, %{})))

    ~H"""
    <li id={@id} class="flex py-6 sm:py-10">
      <div class="shrink-0">
        <CartComponents.variant_image
          variant={@variant}
          height={600}
          width={600}
          class="border border-gray-200 size-24 sm:size-48"
        />
      </div>

      <div class="ml-4 flex flex-1 flex-col justify-between sm:ml-6">
        <div class="relative pr-9 sm:grid sm:grid-cols-2 sm:gap-x-6 sm:pr-0">
          <div>
            <div class="flex justify-between">
              <h3 class="text-sm">
                <.link
                  navigate={"/products/#{@cart_item.variant.product.slug}"}
                  class="font-medium text-gray-700 hover:text-gray-800"
                >
                  {@cart_item.variant.product.name}
                </.link>
              </h3>
            </div>

            <p :if={@variant_description} class="mt-1 text-sm text-gray-500">
              {@variant_description}
            </p>

            <p class="mt-1 text-sm font-medium text-gray-900">
              {@price}
            </p>
          </div>

          <div class="mt-4 sm:mt-0 sm:pr-9">
            <.form
              for={@form}
              id={"cart-item-quantity-#{@cart_item.id}"}
              class="grid w-full max-w-16 grid-cols-1"
              phx-change="update_quantity"
              phx-value-cart_item_id={@cart_item.id}
            >
              <.input
                type="select"
                field={@form[:quantity]}
                options={for n <- 1..5, do: n}
                class="col-start-1 row-start-1 appearance-none rounded-md bg-white py-1.5 pl-3 pr-8 text-base text-gray-900 outline-1 -outline-offset-1 outline-gray-300 focus:outline-2 focus:-outline-offset-2 focus:outline-indigo-600 sm:text-sm/6"
              />
            </.form>

            <div class="absolute top-0 right-0">
              <.button
                type="button"
                variant="link"
                size="custom"
                class="-m-2 p-2 text-gray-400 transition hover:text-gray-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-500"
                phx-click="remove_item"
                phx-value-cart_item_id={@cart_item.id}
              >
                <span class="sr-only">Remove item</span>
                <.icon name="hero-x-mark" class="size-5" />
              </.button>
            </div>
          </div>
        </div>

        <.stock_status variant={@variant} />
      </div>
    </li>
    """
  end

  attr :variant, Variant, required: true

  defp stock_status(assigns) do
    ~H"""
    <p class="mt-4 flex items-center space-x-2 text-sm">
      <%= cond do %>
        <% @variant.inventory_policy != :track_strict or @variant.quantity_available > 0 -> %>
          <.icon name="hero-check" class="size-5 shrink-0 text-green-500" />
          <span class="text-gray-700">In stock</span>
        <% true -> %>
          <.icon name="hero-x-circle" class="size-5 shrink-0 text-red-500" />
          <span class="text-red-500">Out of stock</span>
      <% end %>
    </p>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign_items(socket)}
  end

  @impl true
  def handle_event(
        "update_quantity",
        %{"cart_item_id" => cart_item_id, "cart_item" => cart_item_params},
        socket
      ) do
    cart_item = find_cart_item!(socket.assigns.cart, cart_item_id)

    case Checkout.update_cart_item(socket.assigns.current_scope, cart_item, cart_item_params) do
      {:ok, _updated} ->
        {:noreply, reload_cart(socket)}

      {:error, %Ecto.Changeset{}} ->
        {:noreply,
         socket
         |> put_flash(:error, "We couldn't update that quantity. Please try again.")
         |> reload_cart()}
    end
  end

  @impl true
  def handle_event("remove_item", %{"cart_item_id" => cart_item_id}, socket) do
    cart_item = Checkout.get_cart_item!(socket.assigns.current_scope, cart_item_id)

    case Checkout.delete_cart_item(socket.assigns.current_scope, cart_item) do
      {:ok, _deleted} ->
        {:noreply, reload_cart(socket)}

      {:error, %Ecto.Changeset{}} ->
        {:noreply,
         socket
         |> put_flash(:error, "We couldn't remove that item. Please try again.")
         |> reload_cart()}
    end
  end

  defp assign_items(%{assigns: %{cart: cart}} = socket) do
    items =
      case cart do
        %Cart{items: [_ | _] = items} -> items
        _ -> []
      end

    socket
    |> assign(:empty_cart?, items == [])
    |> stream(:cart_items, items, reset: true)
  end

  defp find_cart_item!(cart, cart_item_id) do
    %CartItem{} = Enum.find(cart.items, &(&1.id == cart_item_id))
  end

  defp reload_cart(socket) do
    cart = Checkout.fetch_active_cart_with_items(socket.assigns.current_scope)

    socket
    |> assign(:cart, cart)
    |> assign_items()
  end
end
