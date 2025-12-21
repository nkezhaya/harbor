defmodule Harbor.Orders do
  @moduledoc """
  The Orders context.
  """
  import Ecto.Query, warn: false

  alias Harbor.Accounts.Scope
  alias Harbor.Customers.Customer
  alias Harbor.Orders.Order
  alias Harbor.Repo

  def get_order!(%Scope{} = scope, id) do
    Order
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

  @admin_roles [:superadmin, :system]

  defp ensure_authorized!(%Scope{role: role}, _order) when role in @admin_roles, do: :ok

  defp ensure_authorized!(%Scope{customer: %Customer{id: customer_id}}, %Order{
         customer_id: customer_id
       }),
       do: :ok

  defp ensure_authorized!(%Scope{}, _order), do: raise(Harbor.UnauthorizedError)
end
