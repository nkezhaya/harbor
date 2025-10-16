defmodule Harbor.CustomersTest do
  use Harbor.DataCase

  import Harbor.AccountsFixtures
  import Harbor.CustomersFixtures

  alias Harbor.{Customers, Repo}
  alias Harbor.Customers.{Address, Customer}

  describe "list_customers/1" do
    test "returns all customers" do
      admin_scope = admin_scope_fixture()
      assert [_ | _] = Customers.list_customers(admin_scope)
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
    test "allows superadmins to create customers with custom status" do
      admin_scope = admin_scope_fixture()
      attrs = Map.put(valid_attrs(), :status, :blocked)

      assert {:ok, %Customer{} = customer} = Customers.create_customer(admin_scope, attrs)
      assert customer.status == :blocked
      assert customer.company_name == attrs.company_name
    end

    test "raises when a guest scope attempts to create a customer" do
      scope = guest_scope_fixture(customer: false)

      assert_raise Harbor.UnauthorizedError, fn ->
        Customers.create_customer(scope, valid_attrs())
      end
    end

    test "raises when an authenticated scope without admin privileges attempts to create a customer" do
      scope = user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Customers.create_customer(scope, valid_attrs())
      end
    end
  end

  describe "update_customer/3" do
    test "allows superadmins to update any customer" do
      admin_scope = admin_scope_fixture()
      customer = customer_fixture(admin_scope)
      attrs = update_attrs()

      assert {:ok, %Customer{} = updated_customer} =
               Customers.update_customer(admin_scope, customer, update_attrs())

      assert updated_customer.company_name == attrs.company_name
      assert updated_customer.email == attrs.email
      assert updated_customer.first_name == attrs.first_name
      assert updated_customer.last_name == attrs.last_name
      assert updated_customer.phone == attrs.phone
    end

    test "allows superadmins to change customer status" do
      admin_scope = admin_scope_fixture()
      customer = customer_fixture(admin_scope)

      assert {:ok, %Customer{} = updated_customer} =
               Customers.update_customer(
                 admin_scope,
                 customer,
                 Map.put(update_attrs(), :status, :blocked)
               )

      assert updated_customer.status == :blocked
    end

    test "raises when a guest scope attempts to update a customer" do
      scope = guest_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Customers.update_customer(scope, scope.customer, update_attrs())
      end
    end

    test "raises when a regular user scope attempts to update a customer" do
      user_scope = user_scope_fixture()
      {:ok, customer} = Customers.save_customer_profile(user_scope, valid_attrs())

      assert_raise Harbor.UnauthorizedError, fn ->
        Customers.update_customer(user_scope, customer, update_attrs())
      end
    end
  end

  describe "save_customer_profile/2" do
    test "creates a customer for a guest scope" do
      scope = guest_scope_fixture(customer: false)

      assert {:ok, %Customer{} = customer} =
               Customers.save_customer_profile(scope, valid_attrs())

      assert customer.company_name == valid_attrs().company_name
      assert customer.email == valid_attrs().email
      assert customer.first_name == valid_attrs().first_name
      assert customer.last_name == valid_attrs().last_name
      assert customer.phone == valid_attrs().phone
      assert customer.status == :active
      assert is_nil(customer.user_id)
    end

    test "returns an error changeset with invalid data" do
      scope = guest_scope_fixture(customer: false)

      assert {:error, %Ecto.Changeset{}} = Customers.save_customer_profile(scope, %{email: nil})
    end

    test "updates an existing customer for the scope" do
      scope = guest_scope_fixture()
      attrs = Map.drop(update_attrs(), [:status])

      assert {:ok, %Customer{} = updated_customer} =
               Customers.save_customer_profile(scope, attrs)

      assert updated_customer.company_name == attrs.company_name
      assert updated_customer.email == attrs.email
      assert updated_customer.first_name == attrs.first_name
      assert updated_customer.last_name == attrs.last_name
      assert updated_customer.phone == attrs.phone
    end

    test "associates the customer to the authenticated user" do
      user_scope = user_scope_fixture()

      assert {:ok, %Customer{} = customer} =
               Customers.save_customer_profile(user_scope, valid_attrs())

      assert customer.user_id == user_scope.user.id
    end

    test "ignores status changes for non-admin scopes" do
      scope = guest_scope_fixture()

      assert {:ok, %Customer{} = customer} =
               Customers.save_customer_profile(
                 scope,
                 Map.put(update_attrs(), :status, :blocked)
               )

      assert customer.status == :active
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

    test "raises when a non-admin scope attempts to delete a customer" do
      scope = guest_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Customers.delete_customer(scope, scope.customer)
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
end
