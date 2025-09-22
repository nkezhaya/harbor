defmodule Harbor.Accounts do
  @moduledoc """
  The Accounts context.
  """
  import Ecto.Query, warn: false

  alias Harbor.Accounts.{Scope, User}
  alias Harbor.Repo

  ## Users

  @doc """
  Returns the list of users.
  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.
  """
  def get_user!(id) do
    Repo.get!(User, id)
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  ## Addresses

  alias Harbor.Accounts.Address

  def list_addresses(%Scope{} = scope) do
    Address
    |> where([a], a.user_id == ^scope.user.id)
    |> Repo.all()
  end

  def get_address!(%Scope{} = scope, id) do
    Address
    |> where([a], a.user_id == ^scope.user.id)
    |> Repo.get!(id)
  end

  def create_address(%Scope{} = scope, attrs) do
    %Address{user_id: scope.user.id}
    |> Address.changeset(attrs)
    |> Repo.insert()
  end

  def update_address(%Scope{} = scope, %Address{} = address, attrs) do
    true = address.user_id == scope.user.id

    address
    |> Address.changeset(attrs)
    |> Repo.update()
  end

  def delete_address(%Scope{} = scope, %Address{} = address) do
    true = address.user_id == scope.user.id

    Repo.delete(address)
  end

  def change_address(%Scope{} = scope, %Address{} = address, attrs \\ %{}) do
    true = address.user_id == scope.user.id

    Address.changeset(address, attrs)
  end

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  ## User registration

  @doc """
  Registers a user.
  """
  def register_user(attrs) do
    %User{}
    |> User.email_changeset(attrs)
    |> Repo.insert()
  end
end
