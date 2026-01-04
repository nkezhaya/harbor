defmodule Harbor.Billing.PaymentProvider.Stripe do
  @moduledoc """
  Stripe-backed implementation of `Harbor.Billing.PaymentProvider`.

  Delegates to the official `:stripe` client to create customers, using the
  request email as an idempotency key so repeated calls remain safe.
  """
  @behaviour Harbor.Billing.PaymentProvider

  alias Harbor.Billing.{PaymentIntent, PaymentProfile}

  @impl Harbor.Billing.PaymentProvider
  def create_payment_profile(params, opts) do
    opts = Keyword.take(opts, [:idempotency_key])

    Stripe.Customer.create(params, opts)
    |> to_result()
  end

  @impl Harbor.Billing.PaymentProvider
  def update_payment_profile(payment_profile, params) do
    Stripe.Customer.update(payment_profile.provider_ref, params)
    |> to_result()
  end

  @impl Harbor.Billing.PaymentProvider
  def create_payment_intent(%PaymentProfile{} = payment_profile, params, opts) do
    params =
      params
      |> Map.put_new(:customer, payment_profile.provider_ref)

    Stripe.PaymentIntent.create(params, opts)
    |> to_result()
  end

  @impl Harbor.Billing.PaymentProvider
  def update_payment_intent(%PaymentIntent{} = payment_intent, params) do
    Stripe.PaymentIntent.update(payment_intent.provider_ref, params)
    |> to_result()
  end

  defp to_result({:ok, _} = result), do: result
  defp to_result({:error, %Stripe.Error{message: message}}), do: {:error, message}
end
