defmodule Harbor.BillingFixtures do
  @moduledoc """
  Test helpers for billing entities such as
  [PaymentProfile](`Harbor.Billing.PaymentProfile`).
  """
  alias Harbor.Billing.PaymentProfile
  alias Harbor.Repo

  @doc """
  Inserts a payment profile for the given scope's customer.
  """
  def payment_profile_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        provider: "stripe",
        provider_ref: "cust_#{System.unique_integer([:positive])}"
      })

    %PaymentProfile{}
    |> PaymentProfile.changeset(attrs, scope)
    |> Repo.insert!()
  end
end
