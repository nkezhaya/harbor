defmodule Harbor.Billing.PaymentIntent do
  @moduledoc """
  Ecto schema that stores payment intent information returned by the configured
  payment provider.
  """
  use Harbor.Schema

  alias Harbor.Billing.PaymentProfile

  @type t() :: %__MODULE__{}

  schema "payment_intents" do
    field :provider, :string
    field :provider_ref, :string
    field :status, :string
    field :amount, :integer
    field :currency, :string
    field :client_secret, :string
    field :metadata, :map, default: %{}

    belongs_to :payment_profile, PaymentProfile

    timestamps()
  end

  @doc false
  def changeset(payment_intent, attrs) do
    payment_intent
    |> cast(attrs, [
      :provider_ref,
      :status,
      :amount,
      :currency,
      :client_secret,
      :metadata,
      :payment_profile_id
    ])
    |> validate_required([:provider_ref, :status, :amount, :currency, :payment_profile_id])
    |> unique_constraint([:provider, :provider_ref])
  end
end
