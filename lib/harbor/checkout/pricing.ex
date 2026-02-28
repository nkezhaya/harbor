defmodule Harbor.Checkout.Pricing do
  @moduledoc """
  Computes pricing information for a checkout [Order](`Harbor.Orders.Order`).

  This module derives a lightweight pricing summary from an order by:

  - Normalizing order items into line items with quantity and unit price
  - Calculating item count and subtotal
  - Carrying over shipping and tax values (if present)
  - Computing a `total_price` from the available amounts

  Use `build/1` to obtain a struct with the keys `:count`,
  `:subtotal`, `:shipping_price`, and `:total_price` suitable for rendering in
  the UI or passing to follow-up workflows.
  """

  alias Harbor.Customers.Address
  alias Harbor.Orders.{Order, OrderItem}
  alias Harbor.Settings
  alias Harbor.Shipping.DeliveryMethod

  defstruct [
    :items,
    count: 0,
    subtotal: Money.zero(:USD),
    shipping_price: Money.zero(:USD),
    tax: nil,
    total_price: Money.zero(:USD),
    meta: %{}
  ]

  @type line_item() :: %{
          id: Ecto.UUID.t(),
          quantity: non_neg_integer(),
          price: Money.t(),
          total_price: Money.t(),
          tax_code_ref: nil
        }

  @type summary() :: %{
          count: non_neg_integer(),
          subtotal: Money.t(),
          shipping_price: nil | Money.t(),
          tax: nil | Money.t(),
          total_price: Money.t()
        }

  @type t() :: %__MODULE__{}

  @doc """
  Returns a summary map for the given order.
  """
  @spec build(Order.t()) :: t()
  def build(%Order{} = order) do
    %__MODULE__{items: Enum.map(order.items, &normalize_item/1)}
    |> put_count()
    |> put_subtotal()
    |> put_shipping(order)
    |> put_tax(order)
    |> put_total()
    |> put_meta(order)
  end

  defp put_count(%__MODULE__{items: items} = pricing) do
    %{pricing | count: Enum.sum_by(items, & &1.quantity)}
  end

  defp put_subtotal(%__MODULE__{items: items} = pricing) do
    subtotal =
      Enum.reduce(items, Money.zero(:USD), fn item, acc ->
        Money.add!(acc, item.total_price)
      end)

    %{pricing | subtotal: subtotal}
  end

  defp put_shipping(%__MODULE__{} = pricing, %Order{} = order) do
    shipping_price =
      if Settings.delivery_enabled?() do
        case order.delivery_method do
          %DeliveryMethod{price: price} -> price
          _ -> Money.zero(:USD)
        end
      else
        Money.zero(:USD)
      end

    %{pricing | shipping_price: shipping_price}
  end

  defp put_tax(%__MODULE__{} = pricing, %Order{tax: tax}) do
    %{pricing | tax: tax}
  end

  defp put_total(%__MODULE__{} = pricing) do
    tax = pricing.tax || Money.zero(:USD)

    total_price =
      pricing.subtotal
      |> Money.add!(pricing.shipping_price)
      |> Money.add!(tax)

    %{pricing | total_price: total_price}
  end

  defp put_meta(%__MODULE__{} = pricing, %Order{} = order) do
    shipping_address =
      case order.shipping_address do
        %Address{} = address ->
          %{
            city: address.city,
            region: address.region,
            postal_code: address.postal_code,
            country: address.country
          }

        _ ->
          nil
      end

    meta = %{shipping_address: shipping_address}

    %{pricing | meta: meta}
  end

  @spec normalize_item(OrderItem.t()) :: line_item()
  defp normalize_item(%OrderItem{} = order_item) do
    quantity = order_item.quantity
    price = order_item.price

    %{
      id: order_item.id,
      quantity: quantity,
      price: price,
      total_price: Money.mult!(price, quantity),
      tax_code_ref: nil
    }
  end
end
