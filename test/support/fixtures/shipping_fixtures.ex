defmodule Harbor.ShippingFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Harbor.Shipping` context.
  """

  # address fixtures moved to AccountsFixtures

  @doc """
  Generate a unique delivery_method name.
  """
  def unique_delivery_method_name, do: "some name#{System.unique_integer([:positive])}"

  @doc """
  Generate a delivery_method.
  """
  def delivery_method_fixture(attrs \\ %{}) do
    {:ok, delivery_method} =
      attrs
      |> Enum.into(%{
        name: unique_delivery_method_name(),
        price: 42,
        fulfillment_type: :ship
      })
      |> Harbor.Shipping.create_delivery_method()

    delivery_method
  end
end
