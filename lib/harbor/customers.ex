defmodule Harbor.Customers do
  @moduledoc """
  The Customers context.
  """
  import Ecto.Query

  alias Harbor.Accounts.Scope
  alias Harbor.Customers.{Address, Customer}
  alias Harbor.Repo

  @admin_roles [:superadmin, :system]

  @doc """
  Returns the list of customers.
  """
  def list_customers(%Scope{role: role}) when role in @admin_roles do
    Customer
    |> where([c], is_nil(c.deleted_at))
    |> Repo.all()
  end

  def list_customers(_scope) do
    raise Harbor.UnauthorizedError, message: "Only admins can view all customers."
  end

  @doc """
  Gets a single customer.

  Raises `Ecto.NoResultsError` if the Customer does not exist.
  """
  def get_customer!(%Scope{} = scope, id) do
    Customer
    |> where([c], is_nil(c.deleted_at))
    |> Repo.get!(id)
    |> tap(&ensure_authorized!(scope, &1))
  end

  @doc """
  Gets the customer for the current scope.
  """
  def get_current_customer!(%Scope{} = scope) do
    Customer
    |> where([c], is_nil(c.deleted_at))
    |> Repo.get!(scope.user.id)
    |> tap(&ensure_authorized!(scope, &1))
  end

  @doc """
  Gets a single customer associated with the given user.
  """
  def get_customer_for_user(%Scope{} = scope, user_id) do
    Customer
    |> Repo.get_by(user_id: user_id)
    |> tap(fn
      nil -> nil
      customer -> ensure_authorized!(scope, customer)
    end)
  end

  @doc """
  Creates a customer.
  """
  def create_customer(%Scope{role: role} = scope, attrs) when role in @admin_roles do
    %Customer{}
    |> Customer.changeset(attrs, scope)
    |> Repo.insert()
  end

  def create_customer(%Scope{}, _attrs) do
    raise Harbor.UnauthorizedError
  end

  @doc """
  Updates a customer.
  """
  def update_customer(%Scope{role: role} = scope, %Customer{} = customer, attrs)
      when role in @admin_roles do
    customer
    |> Customer.changeset(attrs, scope)
    |> Repo.update()
  end

  def update_customer(%Scope{}, _customer, _attrs) do
    raise Harbor.UnauthorizedError
  end

  @doc """
  Deletes a customer.
  """
  def delete_customer(%Scope{role: role} = scope, %Customer{} = customer)
      when role in @admin_roles do
    customer
    |> Customer.changeset(%{deleted_at: DateTime.utc_now()}, scope)
    |> Repo.update()
  end

  def delete_customer(%Scope{}, _customer) do
    raise Harbor.UnauthorizedError
  end

  @doc """
  Saves the profile information for the current scope's customer.

  This is intended for storefront flows where guests or authenticated shoppers
  provide their contact details. If the scope already has a customer record it
  is updated, otherwise a new one is created and associated to the scope's user
  when available.
  """
  def save_customer_profile(%Scope{customer: %Customer{} = customer} = scope, attrs) do
    ensure_authorized!(scope, customer)

    customer
    |> Customer.changeset(attrs, scope)
    |> Repo.update()
  end

  def save_customer_profile(%Scope{} = scope, attrs) do
    scope
    |> build_customer_for_scope()
    |> Customer.changeset(attrs, scope)
    |> Repo.insert()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking customer changes.
  """
  def change_customer(%Scope{} = scope, %Customer{} = customer, attrs \\ %{}) do
    ensure_authorized!(scope, customer)

    Customer.changeset(customer, attrs, scope)
  end

  defp ensure_authorized!(%Scope{role: role}, _customer) when role in @admin_roles, do: :ok
  defp ensure_authorized!(%Scope{customer: %Customer{id: id}}, %Customer{id: id}), do: :ok
  defp ensure_authorized!(%Scope{user: %{id: user_id}}, %Customer{user_id: user_id}), do: :ok
  defp ensure_authorized!(%Scope{}, _customer), do: raise(Harbor.UnauthorizedError)

  defp build_customer_for_scope(%Scope{user: %{id: user_id}}) do
    %Customer{user_id: user_id}
  end

  defp build_customer_for_scope(_scope), do: %Customer{}

  ## Addresses

  def list_addresses(%Scope{} = scope) do
    Address
    |> where([a], a.customer_id == ^scope.customer.id)
    |> Repo.all()
  end

  def get_address!(%Scope{} = scope, id) do
    Address
    |> where([a], a.customer_id == ^scope.customer.id)
    |> Repo.get!(id)
  end

  def create_address(%Scope{} = scope, attrs) do
    %Address{customer_id: scope.customer.id}
    |> Address.changeset(attrs)
    |> Repo.insert()
  end

  def update_address(%Scope{} = scope, %Address{} = address, attrs) do
    true = address.customer_id == scope.customer.id

    address
    |> Address.changeset(attrs)
    |> Repo.update()
  end

  def delete_address(%Scope{} = scope, %Address{} = address) do
    true = address.customer_id == scope.customer.id

    Repo.delete(address)
  end

  def change_address(%Scope{} = scope, %Address{} = address, attrs \\ %{}) do
    true = address.customer_id == scope.customer.id

    Address.changeset(address, attrs)
  end
end
