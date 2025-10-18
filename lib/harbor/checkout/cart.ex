defmodule Harbor.Checkout.Cart do
  @moduledoc """
  Ecto schema for shopping carts and their items.
  """
  use Harbor.Schema

  alias Harbor.Checkout.CartItem
  alias Harbor.Customers.Customer

  @type t() :: %__MODULE__{}

  schema "carts" do
    field :session_token, :string
    field :status, Ecto.Enum, values: [:active, :merged, :expired], default: :active
    field :lock_version, :integer, default: 1
    field :last_touched_at, :utc_datetime_usec
    field :expires_at, :utc_datetime_usec

    has_many :items, CartItem
    belongs_to :customer, Customer

    timestamps()
  end

  @doc false
  def changeset(cart, attrs, scope) do
    cart
    |> cast(attrs, allowed_fields(scope))
    |> put_new_expiration()
    |> optimistic_lock(:lock_version)
    |> apply_scope(scope)
    |> check_constraint(:base,
      name: :customer_or_session_token,
      message: "Customer ID or session token must be set."
    )
  end

  defp put_new_expiration(changeset) do
    case get_field(changeset, :expires_at) do
      nil -> put_last_touched_at(changeset)
      _ -> changeset
    end
  end

  @doc false
  def touched_changeset(cart) do
    cart
    |> put_last_touched_at()
    |> optimistic_lock(:lock_version)
  end

  defp put_last_touched_at(changeset, datetime \\ DateTime.utc_now()) do
    expires_at = DateTime.add(datetime, 30, :day)

    change(changeset, %{last_touched_at: datetime, expires_at: expires_at})
  end

  defp allowed_fields(%Scope{role: :superadmin}), do: [:customer_id, :session_token, :status]
  defp allowed_fields(_scope), do: []

  defp apply_scope(changeset, %Scope{customer: %Customer{id: customer_id}}) do
    change(changeset, %{customer_id: customer_id, session_token: nil})
  end

  defp apply_scope(changeset, %Scope{session_token: session_token})
       when is_binary(session_token) do
    change(changeset, %{customer_id: nil, session_token: session_token})
  end

  defp apply_scope(_changeset, %Scope{}) do
    raise Harbor.UnauthorizedError
  end
end
