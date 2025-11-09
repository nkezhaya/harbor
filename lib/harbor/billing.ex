defmodule Harbor.Billing do
  @moduledoc """
  Billing context entry point that exposes high level helpers for payment
  operations.

  The functions defined here orchestrate the configured payment provider to
  create records that Harbor can persist and use internally.
  """
  alias Harbor.Accounts.Scope
  alias Harbor.Billing.{PaymentProfile, PaymentProvider, SyncPaymentProfileWorker}
  alias Harbor.Config
  alias Harbor.Customers.Customer
  alias Harbor.Repo

  @doc """
  Returns the payment profile record for the given scope. If one is not
  found, it is created.
  """
  @spec find_or_create_payment_profile(Scope.t()) :: {:ok, PaymentProfile.t()} | {:error, term()}
  def find_or_create_payment_profile(%Scope{} = scope) do
    case get_payment_profile(scope, scope.customer.id) do
      nil ->
        params = %{email: scope.customer.email}

        case PaymentProvider.create_payment_profile(params) do
          {:ok, %{id: provider_ref}} ->
            attrs = %{provider: Config.payment_provider(), provider_ref: provider_ref}
            insert_payment_profile!(scope, attrs)

          {:error, _} = error ->
            error
        end

      profile ->
        profile
    end
  end

  defp insert_payment_profile!(%Scope{} = scope, attrs) do
    %PaymentProfile{}
    |> PaymentProfile.changeset(attrs, scope)
    |> Repo.insert!(on_conflict: :nothing, conflict_target: [:provider, :customer_id])
    |> case do
      %PaymentProfile{id: nil} -> get_payment_profile!(scope, scope.customer.id)
      payment_profile -> payment_profile
    end
  end

  def get_payment_profile(%Scope{} = scope, customer_id) do
    ensure_authorized!(scope, customer_id)
    Repo.get_by(PaymentProfile, customer_id: customer_id)
  end

  def get_payment_profile!(%Scope{} = scope, customer_id) do
    ensure_authorized!(scope, customer_id)
    Repo.get_by!(PaymentProfile, customer_id: customer_id)
  end

  defp ensure_authorized!(%Scope{role: :system}, _customer_id), do: :ok
  defp ensure_authorized!(%Scope{customer: %Customer{id: customer_id}}, customer_id), do: :ok
  defp ensure_authorized!(_scope, _customer_id), do: raise(Harbor.UnauthorizedError)

  @doc false
  def enqueue_payment_profile_email_sync(customer_id) do
    %{customer_id: customer_id}
    |> SyncPaymentProfileWorker.new(schedule_in: 15, replace: [scheduled: [:scheduled_at]])
    |> Oban.insert()
  end
end
