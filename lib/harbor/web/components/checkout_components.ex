defmodule Harbor.Web.CheckoutComponents do
  @moduledoc """
  Function components that support the checkout experience.

  These components power the desktop order summary and individual cart item
  rows. Each component expects preloaded data so that templates can render
  without issuing additional database queries.
  """

  use Harbor.Web, :component

  alias Harbor.Catalog.Variant
  alias Harbor.Checkout.Pricing
  alias Harbor.Customers.Address
  alias Harbor.Orders.{Order, OrderItem}
  alias Harbor.Web.CartComponents

  @doc """
  Renders the desktop order summary sidebar for a checkout order.

  Expects an [Order](`Harbor.Orders.Order`) with items and a
  [Pricing](`Harbor.Checkout.Pricing`) summary so that totals can be displayed
  alongside product details.
  """
  attr :order, Order, required: true
  attr :pricing, Pricing, required: true

  def order_summary(assigns) do
    ~H"""
    <section
      aria-labelledby="summary-heading"
      class="hidden w-full max-w-md flex-col bg-gray-50 lg:flex"
    >
      <h2 id="summary-heading" class="sr-only">Order summary</h2>

      <ul role="list" class="flex-auto divide-y divide-gray-200 overflow-y-auto px-6">
        <.order_item :for={item <- @order.items} item={item} class="flex space-x-6 py-6" />
      </ul>

      <div class="sticky bottom-0 flex-none border-t border-gray-200 bg-gray-50 p-6">
        <dl class="space-y-6 text-sm font-medium text-gray-500">
          <div class="flex justify-between">
            <dt>Subtotal</dt>
            <dd class="text-gray-900">{@pricing.subtotal}</dd>
          </div>
          <div class="flex justify-between">
            <dt>Taxes</dt>
            <dd class="text-gray-900">{@pricing.tax || Money.zero(:USD)}</dd>
          </div>
          <div class="flex justify-between">
            <dt>Shipping</dt>
            <dd class="text-gray-900">{@pricing.shipping_price}</dd>
          </div>
          <div class="flex items-center justify-between border-t border-gray-200 pt-6 text-gray-900">
            <dt>Total</dt>
            <dd class="text-base">{@pricing.total_price}</dd>
          </div>
        </dl>
      </div>
    </section>
    """
  end

  @doc """
  Renders a single order item within the order summary list.

  The component relies on the associated variant and product data being
  preloaded so image, description, and pricing details render without extra
  queries. An optional `:class` attribute can be provided to tweak layout
  styling from the call site.
  """
  attr :item, OrderItem, required: true
  attr :class, :string

  def order_item(assigns) do
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
          <p class="text-gray-900">{Money.mult!(@item.price, @item.quantity)}</p>
          <p class="text-gray-500">{Variant.description(@item.variant)}</p>
          <p class="text-gray-500">Qty: {@item.quantity}</p>
        </div>
      </div>
    </li>
    """
  end

  @doc """
  Renders a checkout step shell with summary and body slots.
  """
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :status, :atom, required: true, values: [:upcoming, :current, :complete]
  slot :summary
  slot :body

  def step(assigns) do
    ~H"""
    <div id={"checkout-step-#{@id}"}>
      <button
        type="button"
        phx-click="put_step"
        phx-value-step={@id}
        disabled={@status != :complete}
        class={[
          "flex w-full items-start justify-between py-6 text-left text-lg font-medium",
          @status == :upcoming && "text-gray-400",
          @status == :current && "text-gray-900",
          @status == :complete && "text-gray-700 hover:text-gray-900",
          "cursor-pointer disabled:cursor-auto"
        ]}
      >
        {@label}
      </button>

      <%= case @status do %>
        <% :complete -> %>
          <div class="mt-1 mb-6 text-xs text-gray-600">
            {render_slot(@summary)}
          </div>
        <% :current -> %>
          <div class="mb-6">
            {render_slot(@body)}
          </div>
        <% _ -> %>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a standardized continue/submit button used across checkout steps.
  """
  attr :id, :string, default: nil
  attr :type, :string, default: "submit", values: ~w(submit button)
  attr :class, :string, default: nil
  attr :rest, :global, include: ~w(disabled)
  slot :inner_block, required: true

  def continue_button(assigns) do
    ~H"""
    <button
      type={@type}
      id={@id}
      class={[
        "w-full rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-xs hover:bg-indigo-700 focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 focus:outline-hidden cursor-pointer disabled:cursor-not-allowed disabled:bg-gray-100 disabled:text-gray-500",
        @class
      ]}
      phx-disable-with="Submitting..."
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders a compact, multi-line address summary for checkout steps.
  """
  attr :address, Address, required: true

  def address_summary(assigns) do
    ~H"""
    <span :for={line <- address_summary_lines(@address)} class="block">
      {line}
    </span>
    """
  end

  defp address_summary_lines(%Address{} = address) do
    country = AddressInput.get_country(address.country)
    format = country.local_address_format || country.address_format
    format = format || AddressInput.get_country("US").address_format
    fields = address_field_values(address, country)
    lines = format_address_lines(format, fields)
    lines ++ [country.name]
  end

  defp address_field_values(%Address{} = address, country) do
    %{
      name: address_name(address),
      organization: nil,
      address: address_street(address),
      dependent_locality: nil,
      sublocality: address.city,
      region: address_region(address, country),
      postal_code: address.postal_code,
      sorting_code: nil
    }
  end

  defp address_name(%Address{} = address) do
    case Enum.filter([address.first_name, address.last_name], & &1) do
      [] -> nil
      parts -> Enum.join(parts, " ")
    end
  end

  defp address_street(%Address{} = address) do
    case Enum.filter([address.line1, address.line2], & &1) do
      [] -> nil
      lines -> Enum.join(lines, "\n")
    end
  end

  defp address_region(%Address{region: region}, %AddressInput.Country{subregions: subregions}) do
    case Enum.find(subregions, &(&1.id == region)) do
      %AddressInput.Subregion{} = subregion -> subregion.name
      _ -> nil
    end
  end

  defp format_address_lines(tokens, fields) do
    {lines, current} =
      Enum.reduce(tokens, {[], []}, fn
        :newline, {lines, current} ->
          {[Enum.reverse(current) | lines], []}

        {:text, text}, {lines, current} ->
          {lines, [text | current]}

        {:field, field}, {lines, current} ->
          case Map.get(fields, field) do
            value when is_binary(value) -> {lines, [value | current]}
            _ -> {lines, current}
          end
      end)

    [Enum.reverse(current) | lines]
    |> Enum.reverse()
    |> Enum.map(&IO.iodata_to_binary/1)
    |> Enum.flat_map(&String.split(&1, "\n", trim: true))
  end
end
