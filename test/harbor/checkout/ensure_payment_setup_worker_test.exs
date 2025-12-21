defmodule Harbor.Checkout.EnsurePaymentSetupWorkerTest do
  use Harbor.DataCase, async: true

  import Mox
  import Harbor.CatalogFixtures
  import Harbor.CheckoutFixtures
  import Harbor.CustomersFixtures

  alias Harbor.{Billing, Checkout, Repo}
  alias Harbor.Billing.{PaymentIntent, PaymentProviderMock}
  alias Harbor.Checkout.{EnsurePaymentSetupWorker, Session}
  alias Harbor.Orders.Order

  setup :verify_on_exit!

  test "creates a payment intent for the order" do
    scope = guest_scope_fixture()
    cart = cart_fixture(scope)
    variant = variant_fixture()
    cart_item_fixture(cart, %{variant_id: variant.id})
    session = Checkout.start_checkout(scope, cart)
    order = session.order
    pricing = Checkout.build_pricing(order)

    expect(PaymentProviderMock, :create_payment_profile, fn %{email: email} ->
      assert email == scope.customer.email
      {:ok, %{id: "prof_1"}}
    end)

    expect(PaymentProviderMock, :create_payment_intent, fn %Billing.PaymentProfile{
                                                             provider_ref: "prof_1"
                                                           },
                                                           params,
                                                           opts ->
      assert params.amount == pricing.total_price
      assert params.currency == "usd"

      assert params.metadata == %{"order_id" => session.order_id}

      assert opts == [idempotency_key: "order:#{session.order_id}"]

      {:ok,
       %{
         id: "pi_1",
         status: "requires_payment_method",
         amount: params.amount,
         currency: params.currency,
         client_secret: "secret",
         metadata: params.metadata
       }}
    end)

    assert :ok =
             perform_job(EnsurePaymentSetupWorker, %{
               "customer_id" => scope.customer.id,
               "order_id" => session.order_id
             })

    payment_profile = Billing.get_payment_profile(scope, scope.customer.id)
    intent = Repo.get_by!(PaymentIntent, provider_ref: "pi_1")
    assert intent.payment_profile_id == payment_profile.id

    session = Repo.get!(Session, session.id)
    order = Repo.get!(Order, session.order_id)
    assert order.payment_intent_id == intent.id
  end
end
