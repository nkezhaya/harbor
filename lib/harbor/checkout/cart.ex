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
  def changeset(cart, attrs) do
    cart
    |> cast(attrs, [:session_token])
    |> check_constraint(:base,
      name: :customer_or_session_token,
      message: "Customer ID or session token must be set."
    )
  end
end
