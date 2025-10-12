defmodule HarborWeb.ProductsLive.Show do
  @moduledoc """
  Storefront product detail page.
  """
  use HarborWeb, :live_view

  alias Harbor.{Catalog, Util}
  alias Harbor.Catalog.Product

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} root_categories={@root_categories}>
      <section :if={@product} class="lg:grid lg:grid-cols-2 lg:items-start lg:gap-x-16">
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
                  else: "hover:bg-gray-50"
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
            <%= if @product.default_variant do %>
              <p class="text-3xl tracking-tight text-gray-900">
                {Util.formatted_price(@product.default_variant.price, force_cents: true)}
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
            <button
              type="button"
              class={[
                "flex max-w-xs flex-1 items-center justify-center rounded-md border border-transparent px-8 py-3 text-base font-medium focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 sm:max-w-sm",
                if(@in_stock?,
                  do: "bg-indigo-600 text-white hover:bg-indigo-700",
                  else: "cursor-not-allowed bg-gray-200 text-gray-500"
                )
              ]}
              disabled={not @in_stock?}
              aria-disabled={not @in_stock?}
            >
              Add to bag
            </button>

            <%= if @in_stock? do %>
              <span class="text-sm text-green-600">In stock and ready to ship</span>
            <% else %>
              <span class="text-sm text-gray-500">Currently unavailable</span>
            <% end %>
          </div>
        </div>
      </section>

      <div :if={!@product} class="py-24 text-center text-sm text-gray-500">
        Loading product details...
      </div>
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
       in_stock?: product_in_stock?(product)
     )}
  end

  defp product_in_stock?(%Product{default_variant: %{quantity_available: quantity}}) do
    quantity > 0
  end

  defp product_in_stock?(_), do: false

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
