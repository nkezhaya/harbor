defmodule Harbor.BillingTest do
  use Harbor.DataCase

  import Harbor.AccountsFixtures
  import Harbor.BillingFixtures

  alias Harbor.Billing

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
end
