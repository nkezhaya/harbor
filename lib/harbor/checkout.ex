defmodule Harbor.Checkout do
  @moduledoc """
  The Checkout context.
  """
  import Ecto.Query, warn: false

  alias Harbor.Accounts.{Scope, User}
  alias Harbor.Checkout.{Cart, CartItem, Pricing, Session}
  alias Harbor.Customers.{Address, Customer}
  alias Harbor.Orders.Order
  alias Harbor.{Orders, Repo, Tax}
  alias Harbor.Shipping.DeliveryMethod
  alias Harbor.Tax.{Calculation, Request}

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

  defp ensure_authorized!(%Scope{role: :superadmin}, _cart), do: :ok

  defp ensure_authorized!(%Scope{customer: %Customer{id: customer_id}}, %Cart{
         customer_id: customer_id
       }),
       do: :ok

  defp ensure_authorized!(%Scope{session_token: session_token}, %Cart{
         session_token: session_token
       })
       when is_binary(session_token),
       do: :ok

  defp ensure_authorized!(_scope, _cart), do: raise(Harbor.UnauthorizedError)

  ## Cart Items

  def get_cart_item!(id) do
    Repo.get!(CartItem, id)
  end

  def create_cart_item(%Cart{} = cart, attrs) do
    %CartItem{cart_id: cart.id}
    |> CartItem.changeset(attrs)
    |> Repo.insert()
  end

  def update_cart_item(%CartItem{} = cart_item, attrs) do
    cart_item
    |> CartItem.changeset(attrs)
    |> Repo.update()
  end

  def delete_cart_item(%CartItem{} = cart_item) do
    Repo.delete(cart_item)
  end

  def change_cart_item(%CartItem{} = cart_item, attrs \\ %{}) do
    CartItem.changeset(cart_item, attrs)
  end

  ## Sessions

  defp reload_session(%Session{} = session) do
    session
    |> Repo.reload!()
    |> Repo.preload([
      :billing_address,
      :shipping_address,
      :delivery_method,
      cart: [
        items: [variant: [:tax_code, product: [:tax_code, category: [:tax_code]]]],
        customer: []
      ]
    ])
  end

  def complete_session(%Session{} = session) do
    session
    |> reload_session()
    |> do_complete_session()
  end

  defp do_complete_session(%Session{order_id: nil} = session) do
    with :ok <- ensure_active(session),
         :ok <- ensure_not_expired(session),
         {:ok, email} <- resolve_email(session),
         {:ok, address} <- resolve_address(session),
         {:ok, delivery_method} <- resolve_delivery_method(session),
         {:ok, session} <- update_tax_calculation(session) do
      order_item_attrs =
        Enum.map(session.cart.items, fn %{variant: variant, quantity: quantity} ->
          %{
            variant_id: variant.id,
            quantity: quantity,
            price: variant.price
          }
        end)

      pricing = Pricing.build(session)

      order_attrs = %{
        email: email,
        customer_id: session.cart.customer && session.cart.customer.id,
        items: order_item_attrs,
        address_name: address.name,
        address_line1: address.line1,
        address_line2: address.line2,
        address_city: address.city,
        address_region: address.region,
        address_postal_code: address.postal_code,
        address_country: address.country,
        address_phone: address.phone,
        delivery_method_name: delivery_method.name,
        subtotal: pricing.subtotal,
        tax: pricing.tax,
        shipping_price: pricing.shipping_price
      }

      Repo.transact(fn ->
        with {:ok, order} <- Orders.create_order(order_attrs),
             {:ok, _session} <- put_session_order(session, order) do
          {:ok, order}
        else
          {:error, error} -> Repo.rollback(error)
        end
      end)
    else
      {:error, _} = err -> err
    end
  end

  defp do_complete_session(%Session{} = session) do
    session = Repo.preload(session, [:order])
    {:ok, session.order}
  end

  defp put_session_order(%Session{} = session, %Order{} = order) do
    session
    |> Session.order_changeset(order)
    |> Repo.update()
  end

  defp ensure_active(%Session{status: :active}), do: :ok
  defp ensure_active(%Session{status: :completed}), do: {:error, :already_completed}
  defp ensure_active(%Session{status: :expired}), do: {:error, :session_expired}
  defp ensure_active(%Session{status: :abandoned}), do: {:error, :session_abandoned}

  defp ensure_not_expired(%Session{expires_at: nil}), do: {:error, :missing_expiry}

  defp ensure_not_expired(%Session{expires_at: expires_at}) do
    if DateTime.compare(expires_at, DateTime.utc_now()) == :lt do
      {:error, :session_expired}
    else
      :ok
    end
  end

  defp resolve_email(%Session{} = session) do
    cond do
      is_binary(session.email) and session.email != "" ->
        {:ok, session.email}

      session.cart && session.cart.customer && is_binary(session.cart.customer.email) ->
        {:ok, session.cart.customer.email}

      true ->
        {:error, :missing_email}
    end
  end

  defp resolve_address(%Session{} = session) do
    case session.shipping_address do
      %Address{} = addr -> {:ok, addr}
      _ -> {:error, :missing_address}
    end
  end

  defp resolve_delivery_method(%Session{delivery_method: %DeliveryMethod{} = dm}), do: {:ok, dm}
  defp resolve_delivery_method(%Session{}), do: {:error, :missing_delivery_method}

  @doc """
  Returns the cart with the tax calculation preloaded. If the cart contents have
  changed, it downloads the tax calculation from the provider, then persists it.
  If the cart items and values are unchanged since the last calculation, it
  preloads the last saved calculation.
  """
  def update_tax_calculation(%Session{} = session) do
    session = reload_session(session)
    request = tax_request_from_session(session)
    hash = :erlang.phash2(%{session_id: session.id, request: request})

    case Repo.get_by(Calculation, checkout_session_id: session.id, hash: hash) do
      nil ->
        idempotency_key = "#{session.id},#{hash}"

        with {:ok, response} <- Tax.calculate_taxes(request, idempotency_key) do
          Repo.transact(fn ->
            with {:ok, calculation} <-
                   Tax.create_calculation(%{
                     provider_ref: response.id,
                     checkout_session_id: session.id,
                     amount: response.amount,
                     hash: hash
                   }) do
              line_items =
                for line_item <- response.line_items do
                  %{
                    provider_ref: line_item.id,
                    amount: line_item.amount,
                    cart_item_id: line_item.reference,
                    calculation_id: calculation.id
                  }
                end

              :ok = Tax.upsert_calculation_line_items(line_items)
              {:ok, %{session | current_tax_calculation: calculation}}
            end
          end)
        end

      calculation ->
        {:ok, %{session | current_tax_calculation: calculation}}
    end
  end

  defp tax_request_from_session(%Session{} = session) do
    %Request{
      shipping_price: session.delivery_method.price,
      customer_details: build_customer_details(session.shipping_address),
      line_items: Enum.map(session.cart.items, &line_item_from_pricing/1)
    }
  end

  defp build_customer_details(address) do
    address_params = %{
      region: address.region,
      postal_code: address.postal_code,
      country: address.country
    }

    %{address: address_params, address_source: "shipping"}
  end

  @spec line_item_from_pricing(CartItem.t()) :: Request.line_item()
  defp line_item_from_pricing(item) do
    %{
      price: item.variant.price,
      quantity: item.quantity,
      reference: item.id,
      tax_code_ref: variant_tax_code_ref(item.variant)
    }
  end

  defp variant_tax_code_ref(variant) do
    tax_code = variant.tax_code || variant.product.tax_code || variant.product.category.tax_code
    tax_code.provider_ref
  end
end
