defmodule Harbor.Billing.PaymentProvider do
  @moduledoc """
  Behaviour and dispatcher for external payment providers used by Harbor.

  The concrete provider module is pulled from the `:harbor, :payment_provider`
  configuration and is expected to implement the callbacks defined here.
  """
  alias Harbor.Billing.{PaymentIntent, PaymentProfile}

  @type result(type) :: {:ok, type} | {:error, any()}
  @type payment_intent_response() :: %{
          required(:id) => String.t(),
          required(:status) => String.t(),
          required(:amount) => non_neg_integer(),
          required(:currency) => String.t(),
          required(:client_secret) => String.t(),
          optional(:metadata) => map()
        }

  @callback create_payment_profile(%{required(atom()) => any()}) ::
              result(%{required(:id) => String.t()})
  def create_payment_profile(params) do
    impl().create_payment_profile(params)
  end

  @callback update_payment_profile(PaymentProfile.t(), %{required(atom()) => any()}) ::
              result(%{required(:id) => String.t()})
  def update_payment_profile(payment_profile, params) do
    impl().update_payment_profile(payment_profile, params)
  end

  @callback create_payment_intent(
              PaymentProfile.t(),
              %{required(atom()) => any()},
              keyword()
            ) :: result(payment_intent_response())
  def create_payment_intent(payment_profile, params, opts) do
    impl().create_payment_intent(payment_profile, params, opts)
  end

  @callback update_payment_intent(PaymentIntent.t(), %{required(atom()) => any()}) ::
              result(payment_intent_response())
  def update_payment_intent(payment_intent, params) do
    impl().update_payment_intent(payment_intent, params)
  end

  defp impl do
    {_, module} = Application.get_env(:harbor, :payment_provider)
    module
  end
end
