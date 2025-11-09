defmodule Harbor.Billing.SyncPaymentProfileWorkerTest do
  use Harbor.DataCase

  import Harbor.AccountsFixtures
  import Harbor.BillingFixtures
  import Mox

  alias Harbor.Billing.SyncPaymentProfileWorker
  alias Oban.Job

  setup :set_mox_from_context
  setup :verify_on_exit!

  describe "perform/1" do
    test "updates the provider when a payment profile exists" do
      scope = user_scope_fixture()
      profile = payment_profile_fixture(scope)
      job = %Job{args: %{"customer_id" => scope.customer.id}}

      expect(Harbor.Billing.PaymentProviderMock, :update_payment_profile, fn payment_profile,
                                                                             params ->
        assert payment_profile.id == profile.id
        assert params == %{email: scope.customer.email}
        {:ok, :updated}
      end)

      assert {:ok, :updated} = SyncPaymentProfileWorker.perform(job)
    end

    test "returns skipped when no payment profile exists" do
      scope = user_scope_fixture()
      job = %Job{args: %{"customer_id" => scope.customer.id}}

      assert {:ok, :skipped} = SyncPaymentProfileWorker.perform(job)
    end
  end
end
