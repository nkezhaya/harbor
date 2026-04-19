defmodule Harbor.Web.ProductLive.Show do
  @moduledoc """
  Storefront product detail page.
  """
  use Harbor.Web, :live_view

  alias Harbor.Catalog
  alias Harbor.Catalog.Variant

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      root_taxons={@root_taxons}
      cart={@cart}
    >
      <div class="bg-white">
        <div class="pt-6">
          <nav aria-label="Breadcrumb">
            <ol
              role="list"
              class="mx-auto flex max-w-2xl items-center space-x-2 px-4 sm:px-6 lg:max-w-7xl lg:px-8"
            >
              <li :if={@product.primary_taxon}>
                <div class="flex items-center">
                  <.link
                    navigate={"/shop/#{@product.primary_taxon.slug}"}
                    class="mr-2 text-sm font-medium text-gray-900 hover:text-indigo-600"
                  >
                    {@product.primary_taxon.name}
                  </.link>
                  <.icon name="hero-chevron-right" class="size-4 text-gray-300" />
                </div>
              </li>
              <li class="text-sm">
                <span class="font-medium text-gray-500">{@product.name}</span>
              </li>
            </ol>
          </nav>

          <div class="mx-auto max-w-2xl px-4 pt-10 pb-16 sm:px-6 lg:grid lg:max-w-7xl lg:grid-cols-2 lg:gap-x-8 lg:px-8 lg:pt-16 lg:pb-24">
            <section aria-labelledby="product-gallery">
              <h2 id="product-gallery" class="sr-only">Images</h2>

              <div class="flex flex-col-reverse">
                <div
                  :if={@product.images != []}
                  class="mx-auto mt-6 w-full max-w-2xl lg:max-w-none"
                >
                  <div class="flex gap-4 overflow-x-auto pb-2 sm:grid sm:grid-cols-4 sm:overflow-visible sm:pb-0">
                    <button
                      :for={image <- @product.images}
                      type="button"
                      phx-click="select-image"
                      phx-value-image-id={image.id}
                      aria-pressed={@selected_image && image.id == @selected_image.id}
                      class="relative flex h-24 min-w-24 cursor-pointer items-center justify-center overflow-hidden rounded-md bg-white text-sm font-medium text-gray-900 hover:bg-gray-50 focus:outline-none focus:ring-3 focus:ring-indigo-500/50 focus:ring-offset-4 sm:min-w-0"
                    >
                      <span class="sr-only">{image.alt_text || @product.name}</span>
                      <span class="absolute inset-0 overflow-hidden rounded-md">
                        <img
                          src={ImageHelpers.product_image_url(image, width: 320, height: 320)}
                          alt={image.alt_text || @product.name}
                          class="size-full object-cover"
                        />
                      </span>
                      <span
                        aria-hidden="true"
                        class={[
                          "pointer-events-none absolute inset-0 rounded-md ring-2 ring-offset-2",
                          if(@selected_image && image.id == @selected_image.id,
                            do: "ring-indigo-500",
                            else: "ring-transparent"
                          )
                        ]}
                      />
                    </button>
                  </div>
                </div>

                <div class="overflow-hidden rounded-2xl bg-gray-100 sm:rounded-lg">
                  <%= if @selected_image do %>
                    <img
                      src={ImageHelpers.product_image_url(@selected_image, width: 1400, height: 1600)}
                      alt={@selected_image.alt_text || @product.name}
                      class="aspect-square w-full object-cover"
                    />
                  <% else %>
                    <div class="flex aspect-square items-center justify-center text-sm font-medium text-gray-500">
                      Image coming soon
                    </div>
                  <% end %>
                </div>
              </div>
            </section>

            <section class="mt-10 px-4 sm:mt-16 sm:px-0 lg:mt-0">
              <p
                :if={@product.brand}
                class="text-sm font-semibold uppercase tracking-[0.2em] text-gray-500"
              >
                {@product.brand.name}
              </p>
              <h1 class="mt-2 text-3xl font-bold tracking-tight text-gray-900">
                {@product.name}
              </h1>

              <div class="mt-3 flex items-end justify-between gap-4">
                <div>
                  <h2 class="sr-only">Product information</h2>
                  <p
                    :if={@selected_variant && @has_price?}
                    class="text-3xl tracking-tight text-gray-900"
                  >
                    {@selected_variant.price}
                  </p>
                  <p
                    :if={@option_groups != [] and is_nil(@selected_variant)}
                    class="text-sm text-gray-500"
                  >
                    Select options to see price.
                  </p>
                  <p :if={@option_groups == [] and not @has_price?} class="text-sm text-gray-500">
                    Pricing will be available soon.
                  </p>
                </div>

                <p
                  :if={@selected_variant}
                  class={[
                    "text-sm font-medium",
                    if(@in_stock?, do: "text-emerald-700", else: "text-rose-700")
                  ]}
                >
                  <%= if @in_stock? do %>
                    In stock
                  <% else %>
                    Out of stock
                  <% end %>
                </p>
              </div>

              <div class="mt-6">
                <h2 class="sr-only">Description</h2>

                <div class="space-y-6 text-base text-gray-700">
                  <p>
                    <%= if @product.description do %>
                      {@product.description}
                    <% else %>
                      We are getting the full description ready. Check back soon for more details.
                    <% end %>
                  </p>
                </div>
              </div>

              <div :if={@option_groups != []} class="mt-8 space-y-8">
                <div :for={group <- @option_groups}>
                  <h2 class="text-sm font-medium text-gray-900">{group.name}</h2>

                  <fieldset aria-label={"Choose a #{group.name}"} class="mt-3">
                    <div class="grid grid-cols-2 gap-3 sm:grid-cols-4">
                      <button
                        :for={value <- group.values}
                        type="button"
                        phx-click="select-option"
                        phx-value-option-type-id={group.id}
                        phx-value-option-value-id={value.id}
                        disabled={
                          not option_value_available?(
                            @option_groups,
                            @enabled_variants,
                            @selected_options,
                            group.id,
                            value.id
                          )
                        }
                        class={[
                          "group relative flex cursor-pointer items-center justify-center rounded-md border p-3 text-sm font-medium transition",
                          option_value_button_class(
                            @option_groups,
                            @enabled_variants,
                            @selected_options,
                            group.id,
                            value.id
                          )
                        ]}
                      >
                        {value.name}
                      </button>
                    </div>
                  </fieldset>
                </div>
              </div>

              <div class="mt-8 flex">
                <.button
                  type="button"
                  variant="primary"
                  size="custom"
                  class="flex w-full items-center justify-center rounded-md px-8 py-3 text-base font-medium"
                  phx-click="add_to_cart"
                  phx-value-variant_id={@selected_variant_id}
                  disabled={is_nil(@selected_variant_id) or not @in_stock?}
                  aria-disabled={is_nil(@selected_variant_id) or not @in_stock?}
                >
                  <%= cond do %>
                    <% is_nil(@selected_variant_id) -> %>
                      Select options
                    <% @in_stock? -> %>
                      Add to bag
                    <% true -> %>
                      Out of stock
                  <% end %>
                </.button>
              </div>
            </section>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp option_value_button_class(
         option_groups,
         variants,
         selected_options,
         option_type_id,
         option_value_id
       ) do
    cond do
      Map.get(selected_options, option_type_id) == option_value_id ->
        "border-indigo-600 bg-indigo-600 text-white"

      option_value_available?(
        option_groups,
        variants,
        selected_options,
        option_type_id,
        option_value_id
      ) ->
        "border-gray-300 bg-white text-gray-900 hover:border-gray-400"

      true ->
        "cursor-not-allowed border-gray-200 bg-gray-100 text-gray-400"
    end
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _uri, socket) do
    product = Catalog.get_storefront_product_by_slug!(slug)
    option_groups = build_option_groups(product)

    {:noreply,
     socket
     |> assign(
       product: product,
       enabled_variants: product.enabled_variants,
       option_groups: option_groups,
       selected_image: List.first(product.images)
     )
     |> assign_selection(%{})}
  end

  defp build_option_groups(product) do
    Enum.map(product.product_options, fn product_option ->
      %{id: product_option.id, name: product_option.name, values: product_option.values}
    end)
  end

  @impl true
  def handle_event("select-image", %{"image-id" => image_id}, socket) do
    selected_image =
      Enum.find(socket.assigns.product.images, &(&1.id == image_id)) ||
        List.first(socket.assigns.product.images)

    {:noreply, assign(socket, selected_image: selected_image)}
  end

  def handle_event(
        "select-option",
        %{"option-type-id" => option_type_id, "option-value-id" => option_value_id},
        socket
      ) do
    if option_value_available?(
         socket.assigns.option_groups,
         socket.assigns.enabled_variants,
         socket.assigns.selected_options,
         option_type_id,
         option_value_id
       ) do
      selected_options =
        selected_options_after_click(
          socket.assigns.option_groups,
          socket.assigns.enabled_variants,
          socket.assigns.selected_options,
          option_type_id,
          option_value_id
        )

      {:noreply, assign_selection(socket, selected_options)}
    else
      {:noreply, socket}
    end
  end

  defp option_value_available?(
         option_groups,
         variants,
         selected_options,
         option_type_id,
         option_value_id
       ) do
    selected_options =
      option_groups
      |> selected_options_before(selected_options, option_type_id)
      |> Map.put(option_type_id, option_value_id)

    option_selection_available?(variants, selected_options)
  end

  defp selected_options_after_click(
         option_groups,
         variants,
         selected_options,
         option_type_id,
         option_value_id
       ) do
    base_selection =
      option_groups
      |> selected_options_before(selected_options, option_type_id)
      |> Map.put(option_type_id, option_value_id)

    option_groups
    |> Enum.drop_while(&(&1.id != option_type_id))
    |> tl()
    |> Enum.flat_map(fn group ->
      case Map.fetch(selected_options, group.id) do
        {:ok, selected_value_id} -> [{group.id, selected_value_id}]
        :error -> []
      end
    end)
    |> Enum.reduce(base_selection, fn {group_id, selected_value_id}, acc ->
      next_selection = Map.put(acc, group_id, selected_value_id)

      if option_selection_available?(variants, next_selection) do
        next_selection
      else
        acc
      end
    end)
  end

  defp selected_options_before(option_groups, selected_options, option_type_id) do
    option_groups
    |> Enum.take_while(&(&1.id != option_type_id))
    |> Enum.reduce(%{}, fn group, acc ->
      case Map.fetch(selected_options, group.id) do
        {:ok, selected_value_id} -> Map.put(acc, group.id, selected_value_id)
        :error -> acc
      end
    end)
  end

  defp option_selection_available?(variants, selected_options) do
    Enum.any?(variants, fn variant ->
      option_ids = variant_option_ids(variant)

      Enum.all?(selected_options, fn {option_type_id, option_value_id} ->
        Map.get(option_ids, option_type_id) == option_value_id
      end)
    end)
  end

  defp assign_selection(socket, selected_options) do
    option_groups = socket.assigns.option_groups
    enabled_variants = socket.assigns.enabled_variants

    selected_variant =
      cond do
        option_groups == [] ->
          List.first(enabled_variants)

        Enum.all?(option_groups, &Map.has_key?(selected_options, &1.id)) ->
          exact_matching_variant(enabled_variants, selected_options)

        true ->
          nil
      end

    assign(socket,
      selected_options: selected_options,
      selected_variant: selected_variant,
      selected_variant_id: get_in(selected_variant.id),
      in_stock?: variant_in_stock?(selected_variant),
      has_price?: not is_nil(get_in(selected_variant.price))
    )
  end

  defp variant_in_stock?(%Variant{} = variant) do
    variant.quantity_available > 0 or variant.inventory_policy != :track_strict
  end

  defp variant_in_stock?(_variant), do: false

  defp exact_matching_variant(variants, selected_options) do
    Enum.find(variants, fn variant ->
      option_ids = variant_option_ids(variant)

      Enum.all?(selected_options, fn {option_type_id, option_value_id} ->
        Map.get(option_ids, option_type_id) == option_value_id
      end)
    end)
  end

  defp variant_option_ids(%Variant{} = variant) do
    Enum.reduce(variant.option_values, %{}, fn option_value, acc ->
      Map.put(acc, option_value.product_option_id, option_value.id)
    end)
  end
end
