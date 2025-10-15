defmodule Harbor.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `Harbor.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """
  alias Harbor.Accounts.User
  alias Harbor.Repo

  @type t() :: %__MODULE__{
          role: :guest | :user | :superadmin
        }

  defstruct user: nil, customer: nil, role: :guest, authenticated?: false, session_token: nil

  @doc """
  Creates a scope for guest visitors.
  """
  def for_guest(session_token \\ nil) do
    %__MODULE__{session_token: session_token}
  end

  @doc """
  Creates a scope for the given user.
  """
  def for_user(%User{} = user) do
    user = Repo.preload(user, [:roles])

    role =
      if Enum.any?(user.roles, &(&1.role == :superadmin)) do
        :superadmin
      else
        :user
      end

    %__MODULE__{user: user, role: role, authenticated?: true}
  end
end
