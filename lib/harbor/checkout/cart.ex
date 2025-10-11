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

    has_many :items, CartItem
    belongs_to :customer, Customer

    timestamps()
  end

  @doc false
  def changeset(cart, attrs, scope) do
    cart
    |> cast(attrs, allowed_fields(scope))
    |> apply_scope(scope)
    |> check_constraint(:base,
      name: :customer_or_session_token,
      message: "Customer ID or session token must be set."
    )
  end

  defp allowed_fields(%Scope{superadmin: true}), do: [:customer_id, :session_token]
  defp allowed_fields(_scope), do: []

  defp apply_scope(changeset, %Scope{superadmin: true}), do: changeset

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
