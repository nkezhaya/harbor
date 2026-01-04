defmodule Harbor.Checkout.EnsurePaymentSetupWorkerTest do
  use Harbor.DataCase, async: true

  import Mox
  import Harbor.CatalogFixtures
  import Harbor.CheckoutFixtures
  import Harbor.CustomersFixtures

  alias Harbor.{Billing, Checkout, Repo}
  alias Harbor.Billing.{PaymentIntent, PaymentProviderMock}
  alias Harbor.Checkout.{EnsurePaymentSetupWorker, Session}

  setup :verify_on_exit!

  test "creates a payment intent for the checkout session" do
    scope = guest_scope_fixture()
    cart = cart_fixture(scope)
    variant = variant_fixture()
    cart_item_fixture(cart, %{variant_id: variant.id})
    {:ok, session} = Checkout.create_session(scope, cart)
    order = session.order
    pricing = Checkout.build_pricing(order)

    expect(PaymentProviderMock, :create_payment_profile, fn %{email: email}, opts ->
      assert email == scope.customer.email
      assert opts == [idempotency_key: scope.customer.id]

      {:ok, %{id: "prof_1"}}
    end)

    expect(PaymentProviderMock, :create_payment_intent, fn %Billing.PaymentProfile{
                                                             provider_ref: "prof_1"
                                                           },
                                                           params,
                                                           opts ->
      assert params.amount == pricing.total_price
      assert params.currency == "usd"

      assert params.metadata == %{
               "checkout_session_id" => session.id,
               "order_id" => session.order_id
             }

      assert opts == [idempotency_key: "checkout-session:#{session.id}"]

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

    assert {:ok, _} =
             perform_job(EnsurePaymentSetupWorker, %{
               "customer_id" => scope.customer.id,
               "checkout_session_id" => session.id
             })

    payment_profile = Billing.get_payment_profile(scope, scope.customer.id)
    intent = Repo.get_by!(PaymentIntent, provider_ref: "pi_1")
    assert intent.payment_profile_id == payment_profile.id

    session = Repo.get!(Session, session.id)
    assert session.payment_intent_id == intent.id
  end
end
