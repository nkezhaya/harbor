defmodule Harbor.Billing.PaymentProvider.Stripe do
  @moduledoc """
  Stripe-backed implementation of `Harbor.Billing.PaymentProvider`.

  Delegates to the official `:stripe` client to create customers, using the
  request email as an idempotency key so repeated calls remain safe.
  """
  @behaviour Harbor.Billing.PaymentProvider

  @impl Harbor.Billing.PaymentProvider
  def create_payment_profile(params) do
    Stripe.Customer.create(params, idempotency_key: params[:email])
    |> to_result()
  end

  @impl Harbor.Billing.PaymentProvider
  def update_payment_profile(payment_profile, params) do
    Stripe.Customer.update(payment_profile.provider_ref, params)
    |> to_result()
  end

  defp to_result({:ok, _} = result), do: result
  defp to_result({:error, %Stripe.Error{message: message}}), do: {:error, message}
end
