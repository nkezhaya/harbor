defmodule Harbor.Billing do
  @moduledoc """
  Billing context entry point that exposes high level helpers for payment
  operations.

  The functions defined here orchestrate the configured payment provider to
  create records that Harbor can persist and use internally.
  """
  alias Harbor.Billing.PaymentProfile
  alias Harbor.Repo

  def create_payment_profile(params) do
    %PaymentProfile{}
    |> PaymentProfile.changeset(params)
    |> Repo.insert()
  end
end
