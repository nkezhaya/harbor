defmodule Harbor.Authorization do
  @moduledoc """
  Shared authorization helpers for Harbor contexts.

  These functions centralize scope-based checks so contexts can consistently
  enforce access rules while keeping call sites simple.
  """

  alias Harbor.Accounts.Scope
  alias Harbor.Checkout.Cart
  alias Harbor.Customers.Customer
  alias Harbor.Orders.Order

  @admin_roles [:superadmin, :system]
  defguardp is_admin(role) when role in @admin_roles

  @doc """
  Returns true for admin/system roles.
  """
  def admin?(%Scope{role: role}) do
    is_admin(role)
  end

  @doc """
  Ensures the scope belongs to an admin or system role.

  Returns `:ok` when authorized, otherwise raises `Harbor.UnauthorizedError`.
  """
  def ensure_admin!(%Scope{role: role}) when is_admin(role), do: :ok
  def ensure_admin!(_scope), do: raise(Harbor.UnauthorizedError)

  @doc """
  Ensures the scope has an attached customer or belongs to a non-guest role.

  Returns `:ok` when authorized, otherwise raises `Harbor.UnauthorizedError`.
  """
  def ensure_customer!(%Scope{} = scope) do
    if scope.customer || scope.role != :guest do
      :ok
    else
      raise Harbor.UnauthorizedError
    end
  end

  @doc """
  Ensures the scope is authorized to access the given resource.

  Returns `:ok` when authorized, otherwise raises `Harbor.UnauthorizedError`.
  """
  def ensure_authorized!(%Scope{role: role}, _resource) when is_admin(role), do: :ok

  def ensure_authorized!(%Scope{customer: %Customer{id: customer_id}}, %Order{
        customer_id: customer_id
      }),
      do: :ok

  def ensure_authorized!(%Scope{customer: %Customer{id: customer_id}}, %Cart{
        customer_id: customer_id
      }),
      do: :ok

  def ensure_authorized!(%Scope{session_token: session_token}, %Cart{
        session_token: session_token
      })
      when is_binary(session_token),
      do: :ok

  def ensure_authorized!(%Scope{customer: %Customer{id: customer_id}}, customer_id), do: :ok
  def ensure_authorized!(%Scope{customer: %Customer{id: id}}, %Customer{id: id}), do: :ok
  def ensure_authorized!(%Scope{user: %{id: user_id}}, %Customer{user_id: user_id}), do: :ok

  def ensure_authorized!(_scope, _resource), do: raise(Harbor.UnauthorizedError)
end
