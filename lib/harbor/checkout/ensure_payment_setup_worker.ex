defmodule Harbor.Checkout.EnsurePaymentSetupWorker do
  @moduledoc """
  Ensures a payment profile exists for the customer and creates a payment
  intent for the provided checkout session.
  """
  use Oban.Worker, queue: :billing, unique: [keys: [:customer_id, :checkout_session_id]]

  alias Harbor.Accounts.Scope
  alias Harbor.{Billing, Checkout, Customers, Repo, Util}
  alias Harbor.Checkout.Session

  @impl Oban.Worker
  def perform(%Oban.Job{
        args: %{"customer_id" => customer_id, "checkout_session_id" => checkout_session_id}
      }) do
    scope = Scope.for_system()
    customer = Customers.get_customer!(scope, customer_id)
    scope = %{scope | customer: customer}

    {:ok, profile} = Billing.find_or_create_payment_profile(scope, customer)
    session = fetch_session(checkout_session_id)

    if session.payment_intent_id do
      :ok
    else
      create_payment_intent(profile, session)
    end
  end

  defp create_payment_intent(payment_profile, %Session{} = session) do
    pricing = Checkout.build_pricing(session.order)

    params = %{
      amount: Util.money_to_cents(pricing.total_price),
      currency: String.downcase("#{pricing.total_price.currency}"),
      metadata: %{
        "checkout_session_id" => session.id,
        "order_id" => session.order_id
      }
    }

    opts = [idempotency_key: "checkout-session:#{session.id}"]

    case Billing.create_payment_intent(payment_profile, params, opts) do
      {:ok, payment_intent} ->
        session
        |> Session.payment_intent_changeset(%{payment_intent_id: payment_intent.id})
        |> Repo.update()

      {:error, _} = error ->
        error
    end
  end

  defp fetch_session(checkout_session_id) do
    Session
    |> Repo.get!(checkout_session_id)
    |> Repo.preload([:payment_intent, order: [:delivery_method, :shipping_address, items: []]])
  end
end
