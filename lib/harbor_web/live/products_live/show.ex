defmodule HarborWeb.ProductsLive.Show do
  @moduledoc """
  Storefront product detail page.
  """
  use HarborWeb, :live_view

  alias Harbor.{Catalog, Util}
  alias Harbor.Catalog.{Product, Variant}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      root_categories={@root_categories}
      cart={@cart}
    >
      <section class="lg:grid lg:grid-cols-2 lg:items-start lg:gap-x-16">
        <div>
          <div class="aspect-square w-full overflow-hidden rounded-lg bg-gray-100">
            <%= if @selected_image do %>
              <img
                src={ImageHelpers.product_image_url(@selected_image, width: 1200, height: 1200)}
                alt={@selected_image.alt_text || @product.name}
                class="size-full object-cover"
              />
            <% else %>
              <div class="flex h-full items-center justify-center text-sm font-medium text-gray-500">
                Image coming soon
              </div>
            <% end %>
          </div>

          <div :if={@product.images != []} class="mt-6 grid grid-cols-4 gap-4">
            <button
              :for={image <- @product.images}
              type="button"
              phx-click="select-image"
              phx-value-image-id={image.id}
              aria-pressed={@selected_image && image.id == @selected_image.id}
              class={[
                "relative flex h-24 items-center justify-center overflow-hidden rounded-md bg-white text-sm font-medium uppercase focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2",
                if(@selected_image && image.id == @selected_image.id,
                  do: "ring-2 ring-indigo-500 ring-offset-2",
                  else: "hover:bg-gray-50 cursor-pointer"
                )
              ]}
            >
              <span class="sr-only">{image.alt_text || "#{@product.name} thumbnail"}</span>

              <img
                src={ImageHelpers.product_image_url(image, width: 320, height: 320)}
                alt=""
                class="pointer-events-none size-full object-cover"
              />
            </button>
          </div>
        </div>

        <div class="mt-10 px-0 lg:mt-0">
          <h1 class="text-3xl font-bold tracking-tight text-gray-900">
            {@product.name}
          </h1>

          <div class="mt-4">
            <h2 class="sr-only">Product information</h2>
            <%= if @has_price? do %>
              <p class="text-3xl tracking-tight text-gray-900">
                {Util.formatted_price(@product.default_variant.price)}
              </p>
            <% else %>
              <p class="text-sm text-gray-500">
                Pricing will be available soon.
              </p>
            <% end %>
          </div>

          <div class="mt-6 space-y-4">
            <p class="text-base leading-7 text-gray-500">
              <%= if @product.description do %>
                {@product.description}
              <% else %>
                We are getting the full description ready. Check back soon for more details.
              <% end %>
            </p>
          </div>

          <div class="mt-8 flex flex-col gap-3 sm:flex-row sm:items-center">
            <.button
              type="button"
              variant="primary"
              size="custom"
              class="max-w-xs sm:max-w-sm flex-1 px-8 py-3 text-base"
              phx-click="add_to_cart"
              phx-value-variant_id={@selected_variant_id}
              disabled={not @in_stock?}
              aria-disabled={not @in_stock?}
            >
              <%= if @in_stock? do %>
                Add to bag
              <% else %>
                Out of stock
              <% end %>
            </.button>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _uri, socket) do
    product = Catalog.get_storefront_product_by_slug!(slug)
    selected_image = find_selected_image(product.images, nil)

    {:noreply,
     assign(socket,
       product: product,
       selected_image: selected_image,
       selected_variant_id: product.default_variant_id,
       in_stock?: product_in_stock?(product),
       has_price?: product_has_price?(product)
     )}
  end

  defp product_in_stock?(%Product{default_variant: %Variant{} = variant}) do
    variant.quantity_available > 0 or variant.inventory_policy != :track_strict
  end

  defp product_in_stock?(_product), do: false

  defp product_has_price?(%Product{default_variant: %Variant{price: price}})
       when is_integer(price),
       do: true

  defp product_has_price?(_product), do: false

  @impl true
  def handle_event("select-image", %{"image-id" => image_id}, socket) do
    selected_image = find_selected_image(socket.assigns.product.images, image_id)
    {:noreply, assign(socket, selected_image: selected_image)}
  end

  defp find_selected_image([], _selected_id), do: nil
  defp find_selected_image([image | _], nil), do: image

  defp find_selected_image([image | _] = images, selected_id) do
    case Enum.find(images, &(&1.id == selected_id)) do
      nil -> image
      selected_image -> selected_image
    end
  end
end
