defmodule Harbor.Billing.PaymentProvider do
  @moduledoc """
  Behaviour and dispatcher for external payment providers used by Harbor.

  The concrete provider module is pulled from the `:harbor, :payment_provider`
  configuration and is expected to implement the callbacks defined here.
  """
  alias Harbor.Billing.PaymentProfile

  @type result(type) :: {:ok, type} | {:error, any()}

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

  defp impl do
    {_, module} = Application.get_env(:harbor, :payment_provider)
    module
  end
end
