defmodule Harbor.Checkout.Cart do
  @moduledoc """
  Ecto schema for shopping carts and their items.
  """
  use Harbor.Schema

  alias Harbor.Accounts.User
  alias Harbor.Checkout.CartItem

  @type t() :: %__MODULE__{}

  schema "carts" do
    field :session_token, :string

    has_many :items, CartItem
    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(cart, attrs) do
    cart
    |> cast(attrs, [:session_token])
    |> check_constraint(:base,
      name: :user_or_session_token,
      message: "User ID or session token must be set."
    )
  end
end
