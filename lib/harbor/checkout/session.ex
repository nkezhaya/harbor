defmodule Harbor.Checkout.Session do
  @moduledoc """
  Ecto schema for checkout sessions and payment state.
  """
  use Harbor.Schema

  alias Harbor.Orders.Order

  @type t() :: %__MODULE__{}
  @current_step_values [:contact, :shipping, :delivery, :payment, :review]

  schema "checkout_sessions" do
    field :status, Ecto.Enum,
      values: [:active, :abandoned, :completed, :expired],
      default: :active

    field :current_step, Ecto.Enum, values: @current_step_values

    field :last_touched_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec
    field :current_tax_calculation, :map, virtual: true

    belongs_to :order, Order

    timestamps()
  end

  @doc false
  def changeset(session, attrs) do
    session
    |> cast(attrs, [
      :status,
      :current_step,
      :expires_at
    ])
    |> put_new_expiration()
    |> validate_required([:status, :order_id])
    |> check_constraint(:current_step, name: :check_current_step)
  end

  @doc false
  def touched_changeset(session, datetime \\ DateTime.utc_now()) do
    expires_at = DateTime.add(datetime, 12, :hour)
    change(session, %{last_touched_at: datetime, expires_at: expires_at})
  end

  @doc false
  def completed_changeset(session) do
    change(session, %{status: :completed})
  end

  defp put_new_expiration(changeset) do
    case get_field(changeset, :expires_at) do
      nil -> touched_changeset(changeset)
      _ -> changeset
    end
  end

  def current_step_values, do: @current_step_values
end
