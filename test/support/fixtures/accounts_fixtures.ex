defmodule Harbor.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating entities via the
  `Harbor.Accounts` context.
  """
  import Ecto.Query

  alias Harbor.{Accounts, Auth}
  alias Harbor.Accounts.Scope
  alias Harbor.Auth.{UserRole, UserToken}
  alias Harbor.Repo

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email()
    })
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.register_user()

    user
  end

  def user_fixture(attrs \\ %{}) do
    user = unconfirmed_user_fixture(attrs)

    token =
      extract_user_token(fn url ->
        Auth.deliver_login_instructions(user, url)
      end)

    {:ok, {user, _expired_tokens}} = Auth.login_user_by_magic_link(token)

    user
  end

  def admin_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)

    %UserRole{user_id: user.id, role: :superadmin}
    |> Repo.insert!()

    user
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def admin_scope_fixture do
    admin_fixture() |> user_scope_fixture()
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  def set_password(user) do
    {:ok, {user, _expired_tokens}} =
      Auth.update_user_password(user, %{password: valid_user_password()})

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    UserToken
    |> where([ut], ut.token == ^token)
    |> Repo.update_all(set: [authenticated_at: authenticated_at])
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(), amount_to_add, unit)

    UserToken
    |> where([ut], ut.token == ^token)
    |> Repo.update_all(set: [inserted_at: dt, authenticated_at: dt])
  end
end
