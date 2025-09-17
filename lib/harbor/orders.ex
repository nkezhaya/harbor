defmodule Harbor.Orders do
  @moduledoc """
  The Orders context.
  """
  import Ecto.Query, warn: false

  alias Harbor.Orders.Order
  alias Harbor.Repo

  def list_orders do
    Repo.all(Order)
  end

  def get_order!(id) do
    Repo.get!(Order, id)
  end

  def create_order(attrs) do
    %Order{}
    |> Order.changeset(attrs)
    |> Repo.insert()
  end

  def update_order(%Order{} = order, attrs) do
    order
    |> Order.changeset(attrs)
    |> Repo.update()
  end

  def delete_order(%Order{} = order) do
    Repo.delete(order)
  end

  def change_order(%Order{} = order, attrs \\ %{}) do
    Order.changeset(order, attrs)
  end
end
