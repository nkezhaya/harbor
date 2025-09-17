defmodule Harbor.AccountsTest do
  use Harbor.DataCase

  import Harbor.AccountsFixtures

  alias Harbor.Accounts
  alias Harbor.Accounts.{Address, User}
  alias Harbor.Auth.UserToken

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

  describe "sudo_mode?/2" do
    test "validates the authenticated_at time" do
      now = DateTime.utc_now()

      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.utc_now()})
      assert Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -19, :minute)})
      refute Accounts.sudo_mode?(%User{authenticated_at: DateTime.add(now, -21, :minute)})

      # minute override
      refute Accounts.sudo_mode?(
               %User{authenticated_at: DateTime.add(now, -11, :minute)},
               -10
             )

      # not authenticated
      refute Accounts.sudo_mode?(%User{})
    end
  end

  describe "change_user_email/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_email(%User{})
      assert changeset.required == [:email]
    end
  end

  describe "update_user_email/2" do
    setup do
      user = unconfirmed_user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Harbor.Auth.deliver_user_update_email_instructions(
            %{user | email: email},
            user.email,
            url
          )
        end)

      %{user: user, token: token, email: email}
    end

    test "updates the email with a valid token", %{user: user, token: token, email: email} do
      assert {:ok, %{email: ^email}} = Accounts.update_user_email(user, token)
      changed_user = Repo.get!(User, user.id)
      assert changed_user.email != user.email
      assert changed_user.email == email
      refute Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email with invalid token", %{user: user} do
      assert Accounts.update_user_email(user, "oops") ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if user email changed", %{user: user, token: token} do
      assert Accounts.update_user_email(%{user | email: "current@example.com"}, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end

    test "does not update email if token expired", %{user: user, token: token} do
      {1, nil} = Repo.update_all(UserToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])

      assert Accounts.update_user_email(user, token) ==
               {:error, :transaction_aborted}

      assert Repo.get!(User, user.id).email == user.email
      assert Repo.get_by(UserToken, user_id: user.id)
    end
  end

  describe "change_user_password/3" do
    test "returns a user changeset" do
      assert %Ecto.Changeset{} = changeset = Accounts.change_user_password(%User{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Accounts.change_user_password(
          %User{},
          %{
            "password" => "new valid password"
          },
          hash_password: false
        )

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_user_password/2" do
    test "validates password", %{user: user} do
      {:error, changeset} =
        Accounts.update_user_password(user, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{user: user} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Accounts.update_user_password(user, %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{user: user} do
      {:ok, {user, expired_tokens}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      assert expired_tokens == []
      assert is_nil(user.password)
      assert Accounts.get_user_by_email_and_password(user.email, "new valid password")
    end

    test "deletes all tokens for the given user", %{user: user} do
      _ = Harbor.Auth.generate_user_session_token(user)

      {:ok, {_, _}} =
        Accounts.update_user_password(user, %{
          password: "new valid password"
        })

      refute Repo.get_by(UserToken, user_id: user.id)
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
