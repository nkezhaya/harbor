defmodule Harbor.Checkout.Pricing do
  @moduledoc """
  Computes pricing information for a checkout `Session`.

  This module derives a lightweight pricing summary from a checkout session by:

  - Normalizing cart items into line items with quantity and unit price
  - Calculating item count and subtotal
  - Carrying over shipping and tax values (if present)
  - Computing a `total_price` from the available amounts

  All monetary amounts are integers representing the smallest currency unit (for
  example, cents). Use `get_summary/1` to obtain a map with the keys `:count`,
  `:subtotal`, `:shipping_price`, and `:total_price` suitable for rendering in
  the UI or passing to follow‑up workflows.
  """

  alias Harbor.Checkout.{CartItem, Session}
  alias Harbor.Shipping.DeliveryMethod

  defstruct [:items, count: 0, subtotal: 0, shipping_price: 0, tax: nil, total_price: 0]

  @type line_item() :: %{
          quantity: non_neg_integer(),
          price: non_neg_integer(),
          total_price: non_neg_integer()
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
  @spec get_summary(Session.t()) :: summary()
  def get_summary(%Session{} = session) do
    %__MODULE__{items: Enum.map(session.cart.items, &normalize_item/1)}
    |> put_count()
    |> put_subtotal()
    |> put_shipping(session.delivery_method)
    |> put_total()
    |> to_summary()
  end

  defp put_count(%__MODULE__{items: items} = state) do
    %{state | count: Enum.sum_by(items, & &1.quantity)}
  end

  defp put_subtotal(%__MODULE__{items: items} = state) do
    %{state | subtotal: Enum.sum_by(items, & &1.total_price)}
  end

  defp put_shipping(%__MODULE__{} = state, %DeliveryMethod{fulfillment_type: :pickup}) do
    %{state | shipping_price: 0}
  end

  defp put_shipping(%__MODULE__{} = state, delivery_method) do
    %{state | shipping_price: delivery_method.price}
  end

  defp put_total(%__MODULE__{} = state) do
    total_price =
      state
      |> Map.take([:subtotal, :shipping_price, :tax])
      |> Enum.reduce(0, fn
        {_, nil}, sum -> sum
        {_, value}, sum when is_integer(value) -> value + sum
      end)

    %{state | total_price: total_price}
  end

  defp to_summary(%__MODULE__{} = state) do
    Map.take(state, [:count, :subtotal, :shipping_price, :tax, :total_price])
  end

  @spec normalize_item(CartItem.t()) :: line_item()
  defp normalize_item(%CartItem{} = cart_item) do
    quantity = cart_item.quantity
    price = cart_item.variant.price

    %{quantity: quantity, price: price, total_price: quantity * price}
  end
end
