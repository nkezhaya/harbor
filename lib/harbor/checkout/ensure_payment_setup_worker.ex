defmodule Harbor.Checkout.EnsurePaymentSetupWorker do
  @moduledoc """
  Ensures a payment profile exists for the customer and creates a payment
  intent for the provided order.
  """
  use Oban.Worker, queue: :billing, unique: [keys: [:customer_id, :order_id]]

  alias Harbor.Accounts.Scope
  alias Harbor.{Billing, Checkout, Customers, Orders, Repo}
  alias Harbor.Orders.Order

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"customer_id" => customer_id, "order_id" => order_id}}) do
    scope = Scope.for_system()
    customer = Customers.get_customer!(scope, customer_id)
    scope = %{scope | customer: customer}

    {:ok, profile} = Billing.find_or_create_payment_profile(scope)
    order = fetch_order(order_id)

    create_payment_intent(profile, order)
  end

  defp create_payment_intent(payment_profile, %Order{} = order) do
    pricing = Checkout.build_pricing(order)

    params = %{
      amount: pricing.total_price,
      currency: "usd",
      metadata: %{"order_id" => order.id}
    }

    opts = [idempotency_key: "order:#{order.id}"]

    scope = Scope.for_system()

    with {:ok, intent} <- Billing.create_payment_intent(payment_profile, params, opts),
         {:ok, _} <- Orders.update_order(scope, order, %{payment_intent_id: intent.id}) do
      :ok
    end
  end

  defp fetch_order(order_id) do
    Order
    |> Repo.get!(order_id)
    |> Repo.preload([
      :delivery_method,
      :shipping_address,
      items: []
    ])
  end
end
