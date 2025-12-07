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

  test "creates a payment profile for the customer" do
    scope = guest_scope_fixture()
    customer = scope.customer
    expected_email = customer.email

    expect(PaymentProviderMock, :create_payment_profile, fn %{email: email} ->
      assert email == expected_email
      {:ok, %{id: "prof_123"}}
    end)

    assert :ok = perform_job(EnsurePaymentSetupWorker, %{"customer_id" => customer.id})

    payment_profile = Billing.get_payment_profile(scope, customer.id)
    assert payment_profile.provider_ref == "prof_123"
  end

  test "creates a payment intent for the checkout session" do
    scope = guest_scope_fixture()
    cart = cart_fixture(scope)
    variant = variant_fixture()
    cart_item_fixture(cart, %{variant_id: variant.id})
    session = Checkout.find_or_create_active_session(scope, cart)
    pricing = Checkout.build_pricing(session)

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

      assert params.metadata == %{
               "checkout_session_id" => session.id,
               "cart_id" => cart.id
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

    assert :ok =
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
