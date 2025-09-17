defmodule Harbor.Auth.UserRole do
  @moduledoc """
  Schema for user roles mapping (users_roles).

  Backed by a composite primary key of `user_id` and `role`.
  """
  use Harbor.Schema

  alias Harbor.Accounts.User

  @roles ~w(superadmin admin)a

  @type role() :: :superadmin | :admin
  @type t() :: %__MODULE__{}

  @primary_key false
  schema "users_roles" do
    belongs_to :user, User, primary_key: true
    field :role, Ecto.Enum, values: @roles, primary_key: true

    timestamps(updated_at: false)
  end

  @doc """
  Allowed roles for validation and reference.
  """
  def roles, do: @roles

  @doc """
  Basic changeset for inserting/removing roles.
  """
  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:user_id, :role])
    |> validate_required([:user_id, :role])
    |> check_constraint(:role, name: :check_role)
  end
end
