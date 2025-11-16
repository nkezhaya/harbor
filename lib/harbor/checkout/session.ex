defmodule Harbor.Checkout.Session do
  @moduledoc """
  Ecto schema for checkout sessions and payment state.
  """
  use Harbor.Schema

  alias Harbor.Billing.PaymentIntent
  alias Harbor.Checkout.Cart
  alias Harbor.Customers.Address
  alias Harbor.Orders.Order
  alias Harbor.Shipping.DeliveryMethod
  alias Harbor.Tax.Calculation

  @type t() :: %__MODULE__{}

  schema "checkout_sessions" do
    field :status, Ecto.Enum,
      values: [:active, :abandoned, :completed, :expired],
      default: :active

    field :payment_method_ref, :string
    field :last_touched_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
    field :current_tax_calculation, :map, virtual: true

    belongs_to :cart, Cart
    belongs_to :order, Order
    belongs_to :billing_address, Address
    belongs_to :shipping_address, Address
    belongs_to :delivery_method, DeliveryMethod
    belongs_to :payment_intent, PaymentIntent
    has_many :tax_calculations, Calculation, foreign_key: :checkout_session_id

    timestamps()
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :status,
      :payment_intent_id,
      :payment_method_ref,
      :expires_at,
      :cart_id,
      :billing_address_id,
      :shipping_address_id,
      :delivery_method_id
    ])
    |> put_new_expiration()
    |> validate_required([:status, :cart_id])
  end

  @doc false
  def touched_changeset(session, datetime \\ DateTime.utc_now()) do
    expires_at = DateTime.add(datetime, 12, :hour)
    change(session, %{last_touched_at: datetime, expires_at: expires_at})
  end

  @doc false
  def order_changeset(session, order) do
    change(session, %{order_id: order.id, status: :completed})
  end

  defp put_new_expiration(changeset) do
    case get_field(changeset, :expires_at) do
      nil -> touched_changeset(changeset)
      _ -> changeset
    end
  end
end
