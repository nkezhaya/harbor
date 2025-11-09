defmodule Harbor.Billing do
  @moduledoc """
  Billing context entry point that exposes high level helpers for payment
  operations.

  The functions defined here orchestrate the configured payment provider to
  create records that Harbor can persist and use internally.
  """
  alias Harbor.Accounts.Scope
  alias Harbor.Billing.{PaymentProfile, PaymentProvider}
  alias Harbor.Customers.Customer
  alias Harbor.Repo

  @doc """
  Returns the payment profile record for the given scope. If one is not
  found, it is created.
  """
  @spec find_or_create_payment_profile(Scope.t()) :: {:ok, PaymentProfile.t()} | {:error, term()}
  def find_or_create_payment_profile(%Scope{} = scope) do
    case get_payment_profile(scope) do
      nil ->
        params = %{email: scope.customer.email}

        case PaymentProvider.create_payment_profile(params) do
          {:ok, %{id: provider_ref}} ->
            attrs = %{provider_ref: provider_ref}

            case insert_payment_profile(scope, attrs) do
              %PaymentProfile{id: nil} -> get_payment_profile!(scope)
              payment_profile -> payment_profile
            end

          {:error, _} = error ->
            error
        end

      profile ->
        profile
    end
  end

  defp insert_payment_profile(%Scope{} = scope, attrs) do
    %PaymentProfile{}
    |> PaymentProfile.changeset(attrs, scope)
    |> Repo.insert!(on_conflict: :nothing, conflict_target: [:provider, :customer_id])
  end

  def get_payment_profile(%Scope{customer: %Customer{id: customer_id}}) do
    Repo.get_by(PaymentProfile, customer_id: customer_id)
  end

  def get_payment_profile!(%Scope{customer: %Customer{id: customer_id}}) do
    Repo.get_by!(PaymentProfile, customer_id: customer_id)
  end
end
