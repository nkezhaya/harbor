defmodule Harbor.Customers do
  @moduledoc """
  The Customers context.
  """
  import Ecto.Query
  import Harbor.Authorization

  alias Harbor.Accounts.Scope
  alias Harbor.Customers.{Address, Customer}
  alias Harbor.Repo

  @doc """
  Returns the list of customers.
  """
  def list_customers(%Scope{} = scope) do
    ensure_admin!(scope)

    Customer
    |> where([c], is_nil(c.deleted_at))
    |> Repo.all()
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
  def create_customer(%Scope{} = scope, attrs) do
    ensure_admin!(scope)

    %Customer{}
    |> Customer.changeset(attrs, scope)
    |> Repo.insert()
  end

  @doc """
  Updates a customer.
  """
  def update_customer(%Scope{} = scope, %Customer{} = customer, attrs) do
    ensure_admin!(scope)

    customer
    |> Customer.changeset(attrs, scope)
    |> Repo.update()
  end

  @doc """
  Deletes a customer.
  """
  def delete_customer(%Scope{} = scope, %Customer{} = customer) do
    ensure_admin!(scope)

    customer
    |> Customer.changeset(%{deleted_at: DateTime.utc_now()}, scope)
    |> Repo.update()
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

  defp build_customer_for_scope(%Scope{user: %{id: user_id}}) do
    %Customer{user_id: user_id}
  end

  defp build_customer_for_scope(_scope), do: %Customer{}

  ## Addresses

  def list_addresses(%Scope{} = scope) do
    ensure_authorized!(scope, scope.customer.id)

    Address
    |> where([a], a.customer_id == ^scope.customer.id)
    |> Repo.all()
  end

  def get_address!(%Scope{} = scope, id) do
    ensure_authorized!(scope, scope.customer.id)

    Address
    |> where([a], a.customer_id == ^scope.customer.id)
    |> Repo.get!(id)
  end

  def create_address(%Scope{} = scope, attrs) do
    ensure_authorized!(scope, scope.customer.id)

    %Address{customer_id: scope.customer.id}
    |> Address.changeset(attrs)
    |> Repo.insert()
  end

  def update_address(%Scope{} = scope, %Address{} = address, attrs) do
    ensure_authorized!(scope, address.customer_id)

    address
    |> Address.changeset(attrs)
    |> Repo.update()
  end

  def delete_address(%Scope{} = scope, %Address{} = address) do
    ensure_authorized!(scope, address.customer_id)

    Repo.delete(address)
  end

  def change_address(%Scope{} = scope, %Address{} = address, attrs \\ %{}) do
    ensure_authorized!(scope, address.customer_id)

    Address.changeset(address, attrs)
  end
end
