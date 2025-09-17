defmodule Harbor.Shipping do
  @moduledoc """
  The Shipping context.
  """
  import Ecto.Query, warn: false

  alias Harbor.Repo
  alias Harbor.Shipping.DeliveryMethod

  @doc """
  Returns the list of delivery methods.
  """
  def list_delivery_methods do
    Repo.all(DeliveryMethod)
  end

  @doc """
  Gets a single delivery method.
  """
  def get_delivery_method!(id) do
    Repo.get!(DeliveryMethod, id)
  end

  @doc """
  Creates a delivery method.
  """
  def create_delivery_method(attrs) do
    %DeliveryMethod{}
    |> DeliveryMethod.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a delivery method.
  """
  def update_delivery_method(%DeliveryMethod{} = delivery_method, attrs) do
    delivery_method
    |> DeliveryMethod.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a delivery method.
  """
  def delete_delivery_method(%DeliveryMethod{} = delivery_method) do
    Repo.delete(delivery_method)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking delivery method changes.
  """
  def change_delivery_method(%DeliveryMethod{} = delivery_method, attrs \\ %{}) do
    DeliveryMethod.changeset(delivery_method, attrs)
  end
end
