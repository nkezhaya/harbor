defmodule Harbor.CustomersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Harbor.Customers` context.
  """
  alias Harbor.Accounts.Scope
  alias Harbor.Customers

  @doc """
  Generate a customer.
  """
  def customer_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        company_name: "some company_name",
        email: "customer@example.com",
        first_name: "some first_name",
        last_name: "some last_name",
        phone: "some phone",
        status: :active
      })

    {:ok, customer} =
      case scope.role do
        :superadmin -> Customers.create_customer(scope, attrs)
        _ -> Customers.save_customer_profile(scope, attrs)
      end

    customer
  end

  @doc """
  Generate an address.
  """
  def address_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        first_name: "some first_name",
        last_name: "some last_name",
        line1: "some line1",
        city: "some city",
        country: "some country",
        phone: "some phone"
      })

    {:ok, address} = Customers.create_address(scope, attrs)
    address
  end

  def guest_scope_fixture(opts \\ [customer: %{}])

  def guest_scope_fixture(customer: false) do
    guest_scope()
  end

  def guest_scope_fixture(customer: customer_attrs) do
    scope = guest_scope()
    customer = customer_fixture(scope, customer_attrs)
    %{scope | customer: customer}
  end

  defp guest_scope do
    session_token = "token-#{System.unique_integer()}"
    Scope.for_guest(session_token)
  end
end
