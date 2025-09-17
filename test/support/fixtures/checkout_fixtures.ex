defmodule Harbor.CheckoutFixtures do
  @moduledoc """
  Test helpers for creating entities via the `Harbor.Checkout`
  context.
  """
  alias Harbor.Checkout

  def cart_fixture(attrs \\ %{}) do
    {:ok, cart} =
      attrs
      |> Enum.into(%{session_token: unique_session_token()})
      |> Checkout.create_cart()

    cart
  end

  def cart_item_fixture(cart, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{quantity: 42})
    {:ok, cart_item} = Checkout.create_cart_item(cart, attrs)

    cart_item
  end

  defp unique_session_token, do: "token-#{System.unique_integer([:positive])}"
end
