defmodule Harbor.Orders do
  @moduledoc """
  The Orders context.
  """
  import Ecto.Query, warn: false
  import Harbor.Authorization

  alias Harbor.Accounts.Scope
  alias Harbor.Orders.{Order, OrderQuery}
  alias Harbor.Repo

  def list_orders(%Scope{} = scope, params \\ %{}) do
    query = OrderQuery.new(scope, params)

    Order
    |> where([o], o.status != :draft)
    |> OrderQuery.apply(query)
    |> preload(items: [variant: [:option_values, product: :images]])
    |> Repo.all()
  end

  def get_order!(%Scope{} = scope, id) do
    Order
    |> preload([:customer, items: [variant: :product]])
    |> Repo.get!(id)
    |> tap(&ensure_authorized!(scope, &1))
  end

  def create_order(%Scope{} = scope, attrs) do
    %Order{}
    |> Order.changeset(attrs, scope)
    |> Repo.insert()
  end

  def update_order(%Scope{} = scope, %Order{} = order, attrs) do
    ensure_authorized!(scope, order)

    order
    |> Order.changeset(attrs, scope)
    |> Repo.update()
  end

  def delete_order(%Scope{} = scope, %Order{} = order) do
    ensure_authorized!(scope, order)
    Repo.delete(order)
  end

  def change_order(%Scope{} = scope, %Order{} = order) do
    ensure_authorized!(scope, order)
    Order.changeset(order, %{}, scope)
  end

  def change_order(%Scope{} = scope, %Order{} = order, attrs) do
    ensure_authorized!(scope, order)
    Order.changeset(order, attrs, scope)
  end
end
