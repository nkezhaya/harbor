defmodule Harbor.Checkout.EnsurePaymentSetupWorker do
  @moduledoc """
  Ensures a payment profile exists for the customer and creates a payment
  intent for the provided checkout session.
  """
  use Oban.Worker, queue: :billing, unique: [keys: [:customer_id, :checkout_session_id]]

  alias Harbor.Accounts.Scope
  alias Harbor.Billing
  alias Harbor.Checkout
  alias Harbor.Checkout.Session
  alias Harbor.Customers
  alias Harbor.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"customer_id" => customer_id} = args}) do
    scope = Scope.for_system()
    customer = Customers.get_customer!(scope, customer_id)
    scope = %{scope | customer: customer}

    with {:ok, profile} <- Billing.find_or_create_payment_profile(scope) do
      create_payment_intent(profile, args)
    end
  end

  defp create_payment_intent(payment_profile, %{"checkout_session_id" => session_id})
       when is_binary(session_id) do
    session =
      Session
      |> Repo.get!(session_id)
      |> Repo.preload([
        :delivery_method,
        :shipping_address,
        cart: [
          items: [variant: [:tax_code, product: [:tax_code, category: [:tax_code]]]]
        ]
      ])

    if session.payment_intent_id do
      :ok
    else
      pricing = Checkout.build_pricing(session)

      params = %{
        amount: pricing.total_price,
        currency: "usd",
        metadata: %{
          "checkout_session_id" => session.id,
          "cart_id" => session.cart_id
        }
      }

      opts = [idempotency_key: "checkout-session:#{session.id}"]

      with {:ok, intent} <- Billing.create_payment_intent(payment_profile, params, opts),
           {:ok, _} <-
             session
             |> Session.changeset(%{payment_intent_id: intent.id})
             |> Repo.update() do
        :ok
      end
    end
  end

  defp create_payment_intent(_payment_profile, _args), do: :ok
end
