defmodule Harbor.AccountsTest do
  use Harbor.DataCase

  import Harbor.AccountsFixtures

  alias Harbor.Accounts
  alias Harbor.Accounts.{Address, User}

  setup do
    user = user_fixture()
    scope = user_scope_fixture(user)

    [user: user, scope: scope]
  end

  describe "list_users/0" do
    test "returns all users", %{user: user} do
      assert Accounts.list_users() == [user]
    end
  end

  describe "get_user!/1" do
    test "returns the user with given id", %{user: user} do
      assert Accounts.get_user!(user.id) == user
    end

    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Accounts.get_user!("11111111-1111-1111-1111-111111111111")
      end
    end

    test "returns the user with the given id", %{user: %{id: id} = user} do
      assert %User{id: ^id} = Accounts.get_user!(user.id)
    end
  end

  describe "delete_user/1" do
    test "deletes the user", %{user: user} do
      assert {:ok, %User{}} = Accounts.delete_user(user)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_user!(user.id) end
    end
  end

  describe "get_user_by_email/1" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email("unknown@example.com")
    end

    test "returns the user if the email exists", %{user: %{id: id} = user} do
      assert %User{id: ^id} = Accounts.get_user_by_email(user.email)
    end
  end

  describe "get_user_by_email_and_password/2" do
    test "does not return the user if the email does not exist" do
      refute Accounts.get_user_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the user if the password is not valid", %{user: user} do
      user = set_password(user)
      refute Accounts.get_user_by_email_and_password(user.email, "invalid")
    end

    test "returns the user if the email and password are valid", %{user: %{id: id} = user} do
      user = set_password(user)

      assert %User{id: ^id} =
               Accounts.get_user_by_email_and_password(user.email, valid_user_password())
    end
  end

  describe "register_user/1" do
    test "requires email to be set" do
      {:error, changeset} = Accounts.register_user(%{})

      assert %{email: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates email when given" do
      {:error, changeset} = Accounts.register_user(%{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum values for email for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Accounts.register_user(%{email: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{user: %{email: email}} do
      {:error, changeset} = Accounts.register_user(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Accounts.register_user(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers users without password" do
      email = unique_user_email()
      {:ok, user} = Accounts.register_user(valid_user_attributes(email: email))
      assert user.email == email
      assert is_nil(user.hashed_password)
      assert is_nil(user.confirmed_at)
      assert is_nil(user.password)
    end
  end

  describe "inspect/2" do
    test "does not include password" do
      refute inspect(%User{password: "123456"}) =~ "password: \"123456\""
    end
  end

  test "list_addresses/0 returns all addresses", %{scope: scope} do
    address = address_fixture(scope)
    assert Accounts.list_addresses(scope) == [address]
  end

  test "get_address!/1 returns the address with given id", %{scope: scope} do
    address = address_fixture(scope)
    assert Accounts.get_address!(scope, address.id) == address
  end

  describe "create_address/1" do
    test "with valid data creates an address", %{scope: scope} do
      valid_attrs = %{
        name: "some name",
        line1: "some line1",
        city: "some city",
        country: "some country",
        phone: "some phone"
      }

      assert {:ok, %Address{} = address} = Accounts.create_address(scope, valid_attrs)
      assert address.name == "some name"
      assert address.line1 == "some line1"
      assert address.city == "some city"
      assert address.country == "some country"
      assert address.phone == "some phone"
    end

    test "with invalid data returns error changeset", %{scope: scope} do
      assert {:error, %Ecto.Changeset{}} = Accounts.create_address(scope, %{name: nil})
    end
  end

  describe "update_address/2" do
    test "with valid data updates the address", %{scope: scope} do
      address = address_fixture(scope)

      update_attrs = %{
        name: "some updated name",
        line1: "some updated line1",
        city: "some updated city",
        country: "some updated country",
        phone: "some updated phone"
      }

      assert {:ok, %Address{} = address} = Accounts.update_address(scope, address, update_attrs)
      assert address.name == "some updated name"
      assert address.line1 == "some updated line1"
      assert address.city == "some updated city"
      assert address.country == "some updated country"
      assert address.phone == "some updated phone"
    end

    test "with invalid data returns error changeset", %{scope: scope} do
      address = address_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Accounts.update_address(scope, address, %{
                 first_name: nil,
                 last_name: nil,
                 email: nil,
                 phone: nil
               })

      assert address == Accounts.get_address!(scope, address.id)
    end
  end

  describe "delete_address/1" do
    test "deletes the address", %{scope: scope} do
      address = address_fixture(scope)

      assert {:ok, %Address{}} = Accounts.delete_address(scope, address)
      assert_raise Ecto.NoResultsError, fn -> Accounts.get_address!(scope, address.id) end
    end
  end

  describe "change_address/1" do
    test "returns an address changeset", %{scope: scope} do
      address = address_fixture(scope)

      assert %Ecto.Changeset{} = Accounts.change_address(scope, address)
    end
  end
end
