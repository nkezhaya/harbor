defmodule Harbor.Carts do
  @moduledoc """
  The Carts context.
  """
  import Ecto.Query
  import Harbor.{Authorization, QueryMacros}

  alias Ecto.Changeset
  alias Harbor.Accounts.{Scope, User}
  alias Harbor.Carts.{Cart, CartItem}
  alias Harbor.Catalog.Variant
  alias Harbor.Customers.Customer
  alias Harbor.Repo

  ## Carts

  def get_cart!(%Scope{} = scope, id) do
    Cart
    |> Repo.get!(id)
    |> tap(&ensure_authorized!(scope, &1))
  end

  def create_cart(%Scope{} = scope, attrs) do
    %Cart{}
    |> Cart.changeset(attrs, scope)
    |> Repo.insert()
  end

  def update_cart(%Scope{} = scope, %Cart{} = cart, attrs) do
    ensure_authorized!(scope, cart)

    cart
    |> Cart.changeset(attrs, scope)
    |> Repo.update()
  end

  def delete_cart(%Scope{} = scope, %Cart{} = cart) do
    ensure_authorized!(scope, cart)

    Repo.delete(cart)
  end

  def change_cart(%Scope{} = scope, %Cart{} = cart, attrs \\ %{}) do
    ensure_authorized!(scope, cart)

    Cart.changeset(cart, attrs, scope)
  end

  @doc """
  Ensures there is an active cart for the given scope and returns it.

  The lookup first attempts to load the most recent `:active` cart matching the
  scope. If none exists, it creates one while relying on the unique indexes over
  `(customer_id, status)` and `(session_token, status)` to collapse concurrent
  inserts into a single record. When `opts[:for_update]` is true the query will
  lock the row, making it safe to mutate within a transaction.
  """
  @spec fetch_or_create_active_cart(Scope.t()) :: Cart.t()
  def fetch_or_create_active_cart(%Scope{} = scope, opts \\ []) do
    # Attempt to fetch the current active cart. If one isn't found, try to
    # create one. If the creation fails, it means there was a conflict and we
    # can reattempt to fetch the current active cart.
    query =
      scope
      |> active_cart_query_by_scope()
      |> then(fn query ->
        for_update = Keyword.get(opts, :for_update)
        if for_update, do: lock(query, "FOR UPDATE"), else: query
      end)

    case Repo.one(query) do
      nil -> do_insert_cart(scope) || Repo.one!(query)
      cart -> cart
    end
  end

  defp do_insert_cart(%Scope{} = scope) do
    conflict_field =
      case scope do
        %Scope{customer: %Customer{}} -> "customer_id"
        %Scope{session_token: _session_token} -> "session_token"
      end

    conflict_fragment =
      "(#{conflict_field}) WHERE #{conflict_field} IS NOT NULL AND status = 'active'"

    conflict_target = {:unsafe_fragment, conflict_fragment}

    %Cart{}
    |> Cart.changeset(%{}, scope)
    |> Repo.insert!(on_conflict: :nothing, conflict_target: conflict_target)
    |> case do
      %Cart{id: nil} -> nil
      cart -> cart
    end
  end

  @doc """
  Returns the most recent active cart for the given scope with items preloaded.

  When the scope belongs to a guest, carts are matched on the session token.
  When the scope belongs to an authenticated user, carts are matched on the
  associated customer record.
  """
  @spec fetch_active_cart_with_items(Scope.t()) :: Cart.t() | nil
  def fetch_active_cart_with_items(%Scope{} = scope) do
    scope
    |> active_cart_query_by_scope()
    |> preload([:customer, items: [variant: [:option_values, product: [:images]]]])
    |> Repo.one()
  end

  @doc """
  Returns the customer for the most recent unexpired cart tied to the session token.
  """
  @spec fetch_customer_from_active_cart(String.t()) :: Customer.t() | nil
  def fetch_customer_from_active_cart(session_token) do
    Cart
    |> where([c], c.session_token == ^session_token and c.expires_at > now())
    |> join(:inner, [c], customer in assoc(c, :customer), as: :customer)
    |> where([customer: customer], is_nil(customer.deleted_at))
    |> order_by([c], desc: c.inserted_at)
    |> select([customer: customer], customer)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Inserts or increments a cart item for the scope's active cart.

  The operation runs inside a transaction, ensuring the cart is locked before
  being updated. Repeated attempts from the same user to add the same variant
  will simply increment the quantity rather than creating duplicates.

  Callers must at least provide a `variant_id`, and can optionally send an
  explicit `quantity`.
  """
  def add_item_to_cart(%Scope{} = scope, params) do
    Repo.transact(fn ->
      cart = fetch_or_create_active_cart(scope, for_update: true)

      with {:ok, cart} <- touch_cart(cart) do
        insert_cart_item(cart, params)
      end
    end)
  end

  defp touch_cart(%Cart{} = cart) do
    cart
    |> Cart.touched_changeset()
    |> Repo.update()
  end

  defp insert_cart_item(%Cart{} = cart, params) do
    conflict_query =
      from(CartItem, update: [inc: [quantity: fragment("EXCLUDED.quantity")]])

    %CartItem{cart_id: cart.id}
    |> CartItem.changeset(params)
    |> validate_variant_enabled()
    |> Repo.insert(
      returning: true,
      on_conflict: conflict_query,
      conflict_target: [:cart_id, :variant_id]
    )
  end

  defp active_cart_query_by_scope(%Scope{} = scope) do
    scope
    |> cart_base_query_by_scope()
    |> where([c], c.status == :active)
    |> order_by([c], desc: c.inserted_at)
    |> limit(1)
  end

  defp cart_base_query_by_scope(%Scope{customer: %Customer{id: customer_id}}) do
    where(Cart, [c], c.customer_id == ^customer_id)
  end

  defp cart_base_query_by_scope(%Scope{session_token: session_token})
       when is_binary(session_token) do
    where(Cart, [c], c.session_token == ^session_token)
  end

  defp cart_base_query_by_scope(%Scope{user: %User{} = user}) do
    Cart
    |> join(:inner, [c], assoc(c, :customer), as: :customer)
    |> where([customer: customer], customer.user_id == ^user.id)
  end

  ## Cart Items

  def get_cart_item!(%Scope{} = scope, id) do
    CartItem
    |> Repo.get!(id)
    |> Repo.preload(:cart)
    |> tap(fn cart_item -> ensure_authorized!(scope, cart_item.cart) end)
  end

  def create_cart_item(%Cart{} = cart, attrs) do
    %CartItem{cart_id: cart.id}
    |> CartItem.changeset(attrs)
    |> validate_variant_enabled()
    |> Repo.insert()
  end

  def update_cart_item(%Scope{} = scope, %CartItem{} = cart_item, attrs) do
    cart_item = Repo.preload(cart_item, :cart)
    ensure_authorized!(scope, cart_item.cart)

    cart_item
    |> CartItem.changeset(attrs)
    |> Repo.update()
  end

  def delete_cart_item(%Scope{} = scope, %CartItem{} = cart_item) do
    cart_item = Repo.preload(cart_item, :cart)
    ensure_authorized!(scope, cart_item.cart)

    Repo.delete(cart_item)
  end

  def change_cart_item(%CartItem{} = cart_item, attrs \\ %{}) do
    CartItem.changeset(cart_item, attrs)
  end

  defp validate_variant_enabled(changeset) do
    variant_id = Changeset.get_field(changeset, :variant_id)

    if is_nil(variant_id) or enabled_variant?(variant_id) do
      changeset
    else
      Changeset.add_error(changeset, :variant_id, "is no longer available")
    end
  end

  defp enabled_variant?(variant_id) do
    Variant
    |> where([v], v.id == ^variant_id and v.enabled)
    |> Repo.exists?()
  end
end
