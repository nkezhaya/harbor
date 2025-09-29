defmodule Harbor.Billing.PaymentProfile do
  @moduledoc """
  Ecto schema representing the stored payment profile for a customer, mapped to
  the provider.
  """
  use Harbor.Schema

  alias Harbor.Accounts.User
  alias Harbor.Billing.PaymentMethod

  @type t() :: %__MODULE__{}

  schema "payment_profiles" do
    field :provider, :string
    field :provider_ref, :string
    field :session_token, :string

    belongs_to :user, User
    has_many :payment_methods, PaymentMethod

    timestamps()
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:provider, :provider_ref, :user_id, :session_token])
    |> validate_required([:provider, :provider_ref])
    |> check_constraint(:base,
      name: :user_or_session_token,
      message: "either user_id or session_token must be present"
    )
    |> unique_constraint([:provider, :user_id])
    |> unique_constraint([:provider, :session_token])
    |> unique_constraint([:provider, :provider_ref])
  end
end
