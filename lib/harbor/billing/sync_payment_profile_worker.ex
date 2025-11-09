defmodule Harbor.Billing.SyncPaymentProfileWorker do
  @moduledoc """
  Oban worker that syncs the [Customer](`Harbor.Accounts.Customer`) emails to
  the payment provider's profile record.
  """
  use Oban.Worker, queue: :billing, unique: [period: {15, :seconds}, timestamp: :scheduled_at]

  alias Harbor.Accounts.Scope
  alias Harbor.{Billing, Customers}
  alias Harbor.Billing.PaymentProvider

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"customer_id" => customer_id}}) do
    scope = Scope.for_system()
    customer = Customers.get_customer!(scope, customer_id)

    if payment_profile = Billing.get_payment_profile(scope, customer.id) do
      PaymentProvider.update_payment_profile(payment_profile, %{email: customer.email})
    else
      {:ok, :skipped}
    end
  end
end
