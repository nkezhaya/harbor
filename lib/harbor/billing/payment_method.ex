defmodule Harbor.Billing.PaymentMethod do
  @moduledoc """
  Ecto schema for stored payment methods belonging to a
  [PaymentProfile](`Harbor.Billing.PaymentProfile`).
  """
  use Harbor.Schema

  alias Harbor.Billing.PaymentProfile

  @type t() :: %__MODULE__{}

  schema "payment_methods" do
    field :provider_ref, :string
    field :type, :string
    field :default, :boolean, default: false
    field :details, :map, default: %{}
    field :deleted_at, :utc_datetime_usec

    belongs_to :payment_profile, PaymentProfile

    timestamps()
  end

  @doc false
  def changeset(method, attrs) do
    method
    |> cast(attrs, [
      :provider_ref,
      :type,
      :default,
      :details,
      :deleted_at,
      :payment_profile_id
    ])
    |> validate_required([:provider_ref, :type, :details, :payment_profile_id])
    |> unique_constraint([:provider_ref])
    |> unique_constraint([:payment_profile_id, :default],
      name: :payment_methods_payment_profile_id_default_index,
      message: "only one default payment method is allowed per profile"
    )
  end
end
