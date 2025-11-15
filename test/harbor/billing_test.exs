defmodule Harbor.BillingTest do
  use Harbor.DataCase, async: true

  import Harbor.AccountsFixtures
  import Harbor.BillingFixtures
  import Mox

  alias Harbor.Billing.PaymentIntent
  alias Harbor.{Billing, Config}

  setup :set_mox_from_context
  setup :verify_on_exit!

  describe "find_or_create_payment_profile/1" do
    test "creates a payment profile with provider information" do
      scope = user_scope_fixture()

      expect(Harbor.Billing.PaymentProviderMock, :create_payment_profile, fn params ->
        assert params == %{email: scope.customer.email}
        {:ok, %{id: "cust_mock"}}
      end)

      profile = Billing.find_or_create_payment_profile(scope)

      assert profile.provider == Config.payment_provider()
      assert profile.provider_ref == "cust_mock"
      assert profile.customer_id == scope.customer.id
    end

    test "returns the existing payment profile without calling the provider" do
      scope = user_scope_fixture()
      profile = payment_profile_fixture(scope)

      assert Billing.find_or_create_payment_profile(scope).id == profile.id
    end
  end

  describe "get_payment_profile/2" do
    test "returns the payment profile for the owning scope" do
      scope = user_scope_fixture()
      profile = payment_profile_fixture(scope)

      assert Billing.get_payment_profile(scope, scope.customer.id) == profile
    end

    test "returns nil when no profile exists" do
      scope = user_scope_fixture()

      assert Billing.get_payment_profile(scope, scope.customer.id) == nil
    end

    test "raises when called for another customer" do
      owner_scope = user_scope_fixture()
      payment_profile_fixture(owner_scope)
      other_scope = user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Billing.get_payment_profile(other_scope, owner_scope.customer.id)
      end
    end
  end

  describe "get_payment_profile!/2" do
    test "returns the payment profile for the owning scope" do
      scope = user_scope_fixture()
      profile = payment_profile_fixture(scope)

      assert Billing.get_payment_profile!(scope, scope.customer.id) == profile
    end

    test "raises when the profile is missing" do
      scope = user_scope_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Billing.get_payment_profile!(scope, scope.customer.id)
      end
    end

    test "raises when another scope tries to fetch the profile" do
      owner_scope = user_scope_fixture()
      payment_profile_fixture(owner_scope)
      other_scope = user_scope_fixture()

      assert_raise Harbor.UnauthorizedError, fn ->
        Billing.get_payment_profile!(other_scope, owner_scope.customer.id)
      end
    end
  end

  describe "create_payment_intent/3" do
    test "persists the provider response" do
      scope = user_scope_fixture()
      payment_profile = payment_profile_fixture(scope)
      params = %{amount: 12_00, currency: "usd"}

      expect(Harbor.Billing.PaymentProviderMock, :create_payment_intent, fn ^payment_profile,
                                                                            ^params,
                                                                            opts ->
        assert opts == []

        {:ok,
         %{
           id: "pi_mock",
           status: "requires_payment_method",
           amount: params.amount,
           currency: params.currency,
           client_secret: "pi_secret",
           metadata: %{"cart_id" => "cart_123"}
         }}
      end)

      assert {:ok, %PaymentIntent{} = intent} =
               Billing.create_payment_intent(payment_profile, params)

      assert intent.provider == Config.payment_provider()
      assert intent.provider_ref == "pi_mock"
      assert intent.status == "requires_payment_method"
      assert intent.amount == params.amount
      assert intent.currency == params.currency
      assert intent.client_secret == "pi_secret"
      assert intent.metadata == %{"cart_id" => "cart_123"}
      assert intent.payment_profile_id == payment_profile.id
    end

    test "forwards provider opts" do
      scope = user_scope_fixture()
      payment_profile = payment_profile_fixture(scope)
      params = %{amount: 12_00, currency: "usd"}
      opts = [idempotency_key: "cart_123"]

      expect(Harbor.Billing.PaymentProviderMock, :create_payment_intent, fn ^payment_profile,
                                                                            ^params,
                                                                            ^opts ->
        {:error, :boom}
      end)

      assert {:error, :boom} = Billing.create_payment_intent(payment_profile, params, opts)
    end
  end

  describe "update_payment_intent/2" do
    test "updates the stored payment intent" do
      scope = user_scope_fixture()
      payment_profile = payment_profile_fixture(scope)
      intent = payment_intent_fixture(payment_profile)

      params = %{payment_method: "pm_123"}

      expect(Harbor.Billing.PaymentProviderMock, :update_payment_intent, fn ^intent, ^params ->
        {:ok,
         %{
           id: intent.provider_ref,
           status: "processing",
           amount: intent.amount,
           currency: intent.currency,
           client_secret: "updated_secret",
           metadata: %{"updated" => true}
         }}
      end)

      assert {:ok, %PaymentIntent{} = updated} = Billing.update_payment_intent(intent, params)
      assert updated.id == intent.id
      assert updated.status == "processing"
      assert updated.client_secret == "updated_secret"
      assert updated.metadata == %{"updated" => true}
    end
  end
end
