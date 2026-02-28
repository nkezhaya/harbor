defmodule Harbor.Web.StoreComponents do
  @moduledoc """
  Storefront product components.
  """
  use Harbor.Web, :component

  alias Harbor.Catalog.Product
  alias Harbor.Web.ImageHelpers

  @doc """
  Renders a product card that would appear in the PLP grid.
  """
  attr :product, Product, required: true

  def product_card(assigns) do
    ~H"""
    <a href={"/products/#{@product.slug}"} class="group">
      <.product_image product={@product} />

      <h3 class="mt-4 text-sm text-gray-700">{@product.name}</h3>

      <p class="mt-1 text-lg font-medium text-gray-900">
        <%= if @product.default_variant do %>
          {@product.default_variant.price}
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
end
