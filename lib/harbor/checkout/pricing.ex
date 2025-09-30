defmodule Harbor.Checkout.Pricing do
  @moduledoc """
  Computes pricing information for a checkout `Session`.

  This module derives a lightweight pricing summary from a checkout session by:

  - Normalizing cart items into line items with quantity and unit price
  - Calculating item count and subtotal
  - Carrying over shipping and tax values (if present)
  - Computing a `total_price` from the available amounts

  All monetary amounts are integers representing the smallest currency unit (for
  example, cents). Use `build/1` to obtain a map with the keys `:count`,
  `:subtotal`, `:shipping_price`, and `:total_price` suitable for rendering in
  the UI or passing to follow‑up workflows.
  """

  alias Harbor.Checkout.{CartItem, Session}
  alias Harbor.Customers.Address
  alias Harbor.Shipping.DeliveryMethod

  defstruct [
    :items,
    count: 0,
    subtotal: 0,
    shipping_price: 0,
    tax: nil,
    total_price: 0,
    meta: %{}
  ]

  @type line_item() :: %{
          id: Ecto.UUID.t(),
          quantity: non_neg_integer(),
          price: non_neg_integer(),
          total_price: non_neg_integer(),
          tax_code_ref: nil
        }

  @type summary() :: %{
          count: non_neg_integer(),
          subtotal: non_neg_integer(),
          shipping_price: nil | non_neg_integer(),
          tax: nil | non_neg_integer(),
          total_price: non_neg_integer()
        }

  @type t() :: %__MODULE__{}

  @doc """
  Returns a summary map for the given session.
  """
  @spec build(Session.t()) :: t()
  def build(%Session{} = session) do
    %__MODULE__{items: Enum.map(session.cart.items, &normalize_item/1)}
    |> put_count()
    |> put_subtotal()
    |> put_shipping(session.delivery_method)
    |> put_tax(session.current_tax_calculation)
    |> put_total()
    |> put_meta(session)
  end

  defp put_count(%__MODULE__{items: items} = pricing) do
    %{pricing | count: Enum.sum_by(items, & &1.quantity)}
  end

  defp put_subtotal(%__MODULE__{items: items} = pricing) do
    %{pricing | subtotal: Enum.sum_by(items, & &1.total_price)}
  end

  defp put_shipping(%__MODULE__{} = pricing, %DeliveryMethod{
         fulfillment_type: :ship,
         price: price
       }) do
    %{pricing | shipping_price: price}
  end

  defp put_shipping(%__MODULE__{} = pricing, _delivery_method) do
    %{pricing | shipping_price: 0}
  end

  defp put_tax(%__MODULE__{} = pricing, nil) do
    %{pricing | tax: 0}
  end

  defp put_tax(%__MODULE__{} = pricing, tax_calculation) do
    %{pricing | tax: tax_calculation.amount}
  end

  defp put_total(%__MODULE__{} = pricing) do
    total_price =
      pricing
      |> Map.take([:subtotal, :shipping_price, :tax])
      |> Enum.reduce(0, fn
        {_, nil}, sum -> sum
        {_, value}, sum when is_integer(value) -> value + sum
      end)

    %{pricing | total_price: total_price}
  end

  defp put_meta(%__MODULE__{} = pricing, %Session{} = session) do
    shipping_address =
      case session.shipping_address do
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

  @spec normalize_item(CartItem.t()) :: line_item()
  defp normalize_item(%CartItem{} = cart_item) do
    quantity = cart_item.quantity
    price = cart_item.variant.price

    %{
      id: cart_item.variant.id,
      quantity: quantity,
      price: price,
      total_price: quantity * price,
      tax_code_ref: nil
    }
  end
end
