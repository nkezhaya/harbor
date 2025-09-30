defmodule Harbor.CustomersTest do
  use Harbor.DataCase

  import Harbor.AccountsFixtures
  import Harbor.CustomersFixtures

  alias Harbor.Customers
  alias Harbor.Customers.{Address, Customer}

  describe "list_customers/1" do
    test "returns all customers" do
      scope = guest_scope_fixture()
      admin_scope = admin_scope_fixture()

      assert Customers.list_customers(admin_scope) == [scope.customer]
    end
  end

  describe "get_customer!/2" do
    test "returns the customer for the scope" do
      scope = guest_scope_fixture()
      assert Customers.get_customer!(scope, scope.customer.id) == scope.customer
    end

    test "raises if the customer does not belong to the scope" do
      scope = guest_scope_fixture()
      customer = scope.customer
      other_scope = user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Customers.get_customer!(other_scope, customer.id)
      end
    end

    test "returns the customer for admins" do
      scope = guest_scope_fixture()
      customer = scope.customer
      admin_scope = admin_scope_fixture()

      assert Customers.get_customer!(admin_scope, customer.id) == customer
    end
  end

  describe "create_customer/2" do
    test "with valid data creates a customer" do
      scope = guest_scope_fixture(customer: false)
      assert {:ok, %Customer{} = customer} = Customers.create_customer(scope, valid_attrs())
      assert is_nil(customer.user_id)
      assert customer.company_name == valid_attrs().company_name
      assert customer.email == valid_attrs().email
      assert customer.first_name == valid_attrs().first_name
      assert customer.last_name == valid_attrs().last_name
      assert customer.phone == valid_attrs().phone
      assert customer.status == valid_attrs().status
      refute customer.deleted_at
    end

    test "with invalid data returns error changeset" do
      scope = guest_scope_fixture(customer: false)
      assert {:error, %Ecto.Changeset{}} = Customers.create_customer(scope, invalid_attrs())
    end

    test "does not allow users to override the user_id" do
      user = user_fixture()
      other_user = user_fixture()
      scope = user_scope_fixture(user)
      attrs = Map.put(valid_attrs(), :user_id, other_user.id)

      assert {:ok, %Customer{} = customer} = Customers.create_customer(scope, attrs)
      assert customer.user_id == user.id
    end

    test "allows admins to override the user_id" do
      admin = admin_fixture()
      other_user = user_fixture()
      scope = user_scope_fixture(admin)
      attrs = Map.put(valid_attrs(), :user_id, other_user.id)

      assert {:ok, %Customer{} = customer} = Customers.create_customer(scope, attrs)
      assert customer.user_id == other_user.id
    end
  end

  describe "update_customer/3" do
    test "with valid data updates the customer" do
      scope = guest_scope_fixture()

      assert {:ok, %Customer{} = customer} =
               Customers.update_customer(scope, scope.customer, update_attrs())

      assert customer.company_name == update_attrs().company_name
      assert customer.email == update_attrs().email
      assert customer.first_name == update_attrs().first_name
      assert customer.last_name == update_attrs().last_name
      assert customer.phone == update_attrs().phone
      refute customer.deleted_at
    end

    test "with invalid data returns error changeset" do
      scope = guest_scope_fixture()
      customer = scope.customer

      assert {:error, %Ecto.Changeset{}} =
               Customers.update_customer(scope, customer, invalid_attrs())

      assert customer == Customers.get_customer!(scope, customer.id)
    end

    test "raises if scope does not own the customer" do
      scope = guest_scope_fixture()
      customer = scope.customer
      other_scope = user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Customers.update_customer(other_scope, customer, update_attrs())
      end
    end
  end

  describe "delete_customer/2" do
    test "soft deletes the customer" do
      scope = admin_scope_fixture()
      customer = customer_fixture(scope)
      assert {:ok, %Customer{}} = Customers.delete_customer(scope, customer)

      assert_raise Ecto.NoResultsError, fn ->
        Customers.get_customer!(scope, customer.id)
      end

      customer = Repo.get!(Customer, customer.id)
      assert customer.deleted_at
    end

    test "raises if scope does not own the customer" do
      scope = guest_scope_fixture()
      customer = scope.customer
      other_scope = user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Customers.delete_customer(other_scope, customer)
      end
    end
  end

  describe "change_customer/3" do
    test "returns a changeset for the customer" do
      scope = guest_scope_fixture()
      customer = scope.customer
      assert %Ecto.Changeset{} = Customers.change_customer(scope, customer)
    end
  end

  describe "list_addresses/0" do
    test "returns all addresses" do
      scope = guest_scope_fixture()
      address = address_fixture(scope)
      assert Customers.list_addresses(scope) == [address]
    end
  end

  describe "get_address!/1" do
    test "returns the address with given id" do
      scope = guest_scope_fixture()
      address = address_fixture(scope)
      assert Customers.get_address!(scope, address.id) == address
    end
  end

  describe "create_address/1" do
    test "with valid data creates an address" do
      scope = guest_scope_fixture()

      valid_attrs = %{
        name: "some name",
        line1: "some line1",
        city: "some city",
        country: "some country",
        phone: "some phone"
      }

      assert {:ok, %Address{} = address} = Customers.create_address(scope, valid_attrs)
      assert address.name == "some name"
      assert address.line1 == "some line1"
      assert address.city == "some city"
      assert address.country == "some country"
      assert address.phone == "some phone"
    end

    test "with invalid data returns error changeset" do
      scope = guest_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Customers.create_address(scope, %{name: nil})
    end
  end

  describe "update_address/2" do
    test "with valid data updates the address" do
      scope = guest_scope_fixture()
      address = address_fixture(scope)

      update_attrs = %{
        name: "some updated name",
        line1: "some updated line1",
        city: "some updated city",
        country: "some updated country",
        phone: "some updated phone"
      }

      assert {:ok, %Address{} = address} = Customers.update_address(scope, address, update_attrs)
      assert address.name == "some updated name"
      assert address.line1 == "some updated line1"
      assert address.city == "some updated city"
      assert address.country == "some updated country"
      assert address.phone == "some updated phone"
    end

    test "with invalid data returns error changeset" do
      scope = guest_scope_fixture()
      address = address_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Customers.update_address(scope, address, %{
                 first_name: nil,
                 last_name: nil,
                 email: nil,
                 phone: nil
               })

      assert address == Customers.get_address!(scope, address.id)
    end
  end

  describe "delete_address/1" do
    test "deletes the address" do
      scope = guest_scope_fixture()
      address = address_fixture(scope)

      assert {:ok, %Address{}} = Customers.delete_address(scope, address)
      assert_raise Ecto.NoResultsError, fn -> Customers.get_address!(scope, address.id) end
    end
  end

  describe "change_address/1" do
    test "returns an address changeset" do
      scope = guest_scope_fixture()
      address = address_fixture(scope)

      assert %Ecto.Changeset{} = Customers.change_address(scope, address)
    end
  end

  defp valid_attrs do
    %{
      company_name: "Acme Co.",
      email: "customer@example.com",
      first_name: "Jane",
      last_name: "Doe",
      phone: "555-0100",
      status: :active
    }
  end

  defp update_attrs do
    %{
      company_name: "Updated Co.",
      email: "updated@example.com",
      first_name: "Janet",
      last_name: "Smith",
      phone: "555-0110",
      status: :blocked
    }
  end

  defp invalid_attrs do
    %{
      company_name: nil,
      email: nil,
      first_name: nil,
      last_name: nil,
      phone: nil,
      status: nil
    }
  end
end
