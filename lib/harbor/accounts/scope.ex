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
  alias Harbor.Customers.Customer
  alias Harbor.Repo

  defstruct user: nil, customer: nil, superadmin: false, session_token: nil

  @doc """
  Creates a scope for guest visitors.
  """
  def for_guest(session_token \\ nil) do
    %__MODULE__{session_token: session_token}
  end

  @doc """
  Creates a scope for the given user.

  Returns nil if no user is given.
  """
  def for_user(%User{} = user) do
    user = Repo.preload(user, [:roles])
    superadmin = Enum.any?(user.roles, &(&1.role == :superadmin))
    %__MODULE__{user: user, superadmin: superadmin}
  end

  def for_user(nil) do
    nil
  end

  @doc """
  Creates a scope for the given customer.

  Returns nil if no customer is given.
  """
  def for_customer(%Customer{} = customer) do
    %__MODULE__{customer: customer}
  end

  def for_customer(nil) do
    nil
  end

  @doc """
  Attaches the customer to the given scope.
  """
  def attach_customer(%__MODULE__{} = scope, %Customer{} = customer) do
    %{scope | customer: customer}
  end

  @doc """
  Attaches the session token to the given scope.
  """
  def attach_session_token(%__MODULE__{} = scope, session_token) do
    %{scope | session_token: session_token}
  end
end
