defmodule Harbor.BillingFixtures do
  @moduledoc """
  Test helpers for billing entities such as
  [PaymentProfile](`Harbor.Billing.PaymentProfile`) and
  [PaymentIntent](`Harbor.Billing.PaymentIntent`).
  """
  alias Harbor.Billing.{PaymentIntent, PaymentProfile, PaymentProvider}
  alias Harbor.Repo

  @doc """
  Inserts a payment profile for the given scope's customer.
  """
  def payment_profile_fixture(scope, attrs \\ %{}) do
    attrs = Enum.into(attrs, %{provider_ref: "cust_#{System.unique_integer([:positive])}"})

    %PaymentProfile{provider: PaymentProvider.name()}
    |> PaymentProfile.changeset(attrs, scope)
    |> Repo.insert!()
  end

  @doc """
  Inserts a payment intent tied to the given payment profile.
  """
  def payment_intent_fixture(payment_profile, attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        provider_ref: "pi_#{System.unique_integer([:positive])}",
        status: "requires_payment_method",
        amount: 1000,
        currency: "usd",
        client_secret: "secret_#{System.unique_integer([:positive])}",
        metadata: %{}
      })
      |> Map.put(:payment_profile_id, payment_profile.id)

    %PaymentIntent{provider: PaymentProvider.name()}
    |> PaymentIntent.changeset(attrs)
    |> Repo.insert!()
  end
end
