defmodule Harbor.Checkout do
  @moduledoc """
  The Checkout context.
  """
  import Ecto.Query, warn: false
  import Harbor.Authorization

  alias Harbor.Accounts.{Scope, User}
  alias Harbor.Checkout.{Cart, CartItem, EnsurePaymentSetupWorker, Pricing, Session}
  alias Harbor.Customers.{Address, Customer}
  alias Harbor.{Customers, Orders, Repo, Tax}
  alias Harbor.Orders.{Order, OrderItem}
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

  ## Sessions

  @doc """
  Creates a checkout session for the cart by creating a draft order.

  The provided [Scope](`Harbor.Accounts.Scope`) is authorized against the cart
  before any work is done. The order is created from the cart items and linked
  to a new active session. The resulting session is preloaded with the
  associations required by pricing and tax calculations.
  """
  @spec create_session(Scope.t(), Cart.t()) ::
          {:ok, Session.t()} | {:error, Ecto.Changeset.t()}
  def create_session(%Scope{} = scope, %Cart{} = cart) do
    ensure_authorized!(scope, cart)

    cart = Repo.preload(cart, items: [:variant])

    Repo.transact(fn ->
      with {:ok, order} <- create_draft_order(cart) do
        session =
          %Session{order_id: order.id}
          |> Session.changeset(%{})
          |> Repo.insert!()

        {:ok, preload_session(session)}
      end
    end)
  end

  defp create_draft_order(%Cart{} = cart) do
    order_item_attrs =
      Enum.map(cart.items, fn %CartItem{variant: variant, quantity: quantity} ->
        %{variant_id: variant.id, quantity: quantity, price: variant.price}
      end)

    order_attrs = %{
      cart_id: cart.id,
      customer_id: cart.customer_id,
      items: order_item_attrs
    }

    scope = Scope.for_system()
    Orders.create_order(scope, order_attrs)
  end

  @doc """
  Fetches a checkout session by id for the given scope.

  Returns `{:ok, session}` when the session is active and unexpired, otherwise
  returns `{:error, reason}`.
  """
  @type session_error ::
          :not_found
          | :already_completed
          | :session_expired
          | :session_abandoned
          | :missing_expiry

  @spec get_session(Scope.t(), Ecto.UUID.t()) :: {:ok, Session.t()} | {:error, session_error()}
  def get_session(%Scope{} = scope, id) do
    case Repo.get(Session, id) do
      nil ->
        {:error, :not_found}

      %Session{} = session ->
        session = preload_session(session)
        ensure_authorized!(scope, session.order.cart)

        with :ok <- ensure_active(session),
             :ok <- ensure_not_expired(session) do
          {:ok, touch_session!(session)}
        end
    end
  end

  defp ensure_active(%Session{status: status}) do
    case status do
      :active -> :ok
      :completed -> {:error, :already_completed}
      :expired -> {:error, :session_expired}
      :abandoned -> {:error, :session_abandoned}
    end
  end

  defp ensure_not_expired(%Session{expires_at: expires_at}) do
    if DateTime.compare(expires_at, DateTime.utc_now()) == :lt do
      {:error, :session_expired}
    else
      :ok
    end
  end

  defp touch_session!(%Session{} = session) do
    session
    |> Session.touched_changeset()
    |> Repo.update!()
    |> preload_session()
  end

  defp reload_session(%Session{} = session) do
    session
    |> Repo.reload!()
    |> preload_session()
  end

  @doc """
  Completes the contact step by saving the customer profile and enqueueing
  payment profile setup work.

  Returns `{:ok, session, scope}` with the updated scope containing the saved
  customer, or `{:error, changeset}` when validation fails.
  """
  @spec complete_contact_step(Scope.t(), Session.t(), map()) ::
          {:ok, Session.t(), Scope.t()} | {:error, Ecto.Changeset.t()} | {:error, term()}
  def complete_contact_step(%Scope{} = scope, %Session{} = session, params) do
    session = Repo.preload(session, order: [:cart])

    Repo.transact(fn ->
      order = session.order

      with {:ok, customer} <- Customers.save_customer_profile(scope, params),
           {:ok, _cart} <-
             update_cart(Scope.for_system(), order.cart, %{customer_id: customer.id}),
           {:ok, _order} <-
             Orders.update_order(Scope.for_system(), order, %{
               customer_id: customer.id,
               email: customer.email
             }) do
        scope = Scope.attach_customer(scope, customer)
        enqueue_payment_setup(customer.id, session.id)

        {:ok, {session, scope}}
      end
    end)
    |> case do
      {:ok, {session, scope}} -> {:ok, reload_session(session), scope}
      error -> error
    end
  end

  defp enqueue_payment_setup(customer_id, checkout_session_id) do
    %{"customer_id" => customer_id, "checkout_session_id" => checkout_session_id}
    |> EnsurePaymentSetupWorker.new()
    |> Oban.insert()
  end

  @doc """
  Completes the shipping step by upserting a shipping address for the current
  scope's customer and attaching it to the order.

  Returns `{:ok, session}` with the updated order on success, or
  `{:error, changeset}` when validation fails.
  """
  @spec complete_shipping_step(Scope.t(), Session.t(), map()) ::
          {:ok, Session.t()} | {:error, Ecto.Changeset.t()} | {:error, term()}
  def complete_shipping_step(%Scope{} = scope, %Session{} = session, params) do
    session = Repo.preload(session, order: [:cart, :shipping_address])
    ensure_authorized!(scope, session.order.cart)

    Repo.transact(fn ->
      with {:ok, address} <- upsert_shipping_address(scope, session.order, params),
           {:ok, _order} <-
             Orders.update_order(scope, session.order, %{shipping_address_id: address.id}) do
        {:ok, session}
      end
    end)
    |> case do
      {:ok, session} -> {:ok, reload_session(session)}
      error -> error
    end
  end

  defp upsert_shipping_address(%Scope{} = scope, %Order{} = order, params) do
    case order.shipping_address do
      %Address{} = address -> Customers.update_address(scope, address, params)
      _ -> Customers.create_address(scope, params)
    end
  end

  @doc """
  Computes the ordered checkout steps for the given scope, order, and pricing.

  - Adds `:contact` when the scope is not authenticated.
  - Adds `:shipping` and `:delivery` when any order item is a physical product.
  - Adds `:payment` when the order total is greater than zero.
  - Always appends `:review` as the final step.
  """
  @spec checkout_steps(Scope.t(), Order.t(), Pricing.t()) :: [atom()]
  def checkout_steps(%Scope{} = scope, %Order{} = order, %Pricing{} = pricing) do
    steps =
      if scope.authenticated? do
        []
      else
        [:contact]
      end

    steps =
      if Enum.any?(order.items, & &1.variant.product.physical_product) do
        steps ++ [:shipping, :delivery]
      else
        steps
      end

    steps =
      if pricing.total_price > 0 do
        steps ++ [:payment]
      else
        steps
      end

    steps ++ [:review]
  end

  @doc """
  Normalizes the session's `current_step` against the provided steps.

  If the current step is invalid, it is set to the first step. If any prior step
  has not been completed, the current step is rewound to the first incomplete
  step. Expects a non-empty `steps` list and raises when persisting the updated
  step fails.
  """
  def ensure_valid_current_step!(%Scope{} = scope, %Session{} = session, [first | _] = steps) do
    validated_step =
      cond do
        session.current_step not in steps ->
          first

        session.current_step == first ->
          first

        true ->
          steps
          |> Enum.find(&(not did_complete?(session, &1)))
          |> case do
            nil -> List.last(steps)
            incomplete_step -> incomplete_step
          end
      end

    case update_session(scope, session, %{current_step: validated_step}) do
      {:ok, session} ->
        session

      {:error, changeset} ->
        raise ArgumentError, "failed to update session: #{inspect(changeset.errors)}"
    end
  end

  defp did_complete?(%Session{} = session, :contact) do
    case session.order.customer do
      %Customer{email: email} -> is_binary(email)
      _ -> false
    end
  end

  defp did_complete?(_session, _step), do: false

  @doc """
  Updates a checkout session when the given scope owns the backing order cart.

  Preloads associations on success and returns `{:ok, session}` or
  `{:error, changeset}`. Raises `Harbor.UnauthorizedError` when the scope does
  not own the cart.
  """
  def update_session(%Scope{} = scope, %Session{} = session, attrs) do
    session = Repo.preload(session, order: [:cart])
    ensure_authorized!(scope, session.order.cart)

    session
    |> Session.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, session} -> {:ok, preload_session(session)}
      {:error, _} = error -> error
    end
  end

  defp preload_session(%Session{} = session) do
    Repo.preload(session,
      payment_intent: [],
      order: [
        :cart,
        :customer,
        :billing_address,
        :shipping_address,
        :delivery_method,
        items: [
          variant: [
            :tax_code,
            :option_values,
            product: [:images, :tax_code, category: [:tax_code]]
          ]
        ]
      ]
    )
  end

  @doc """
  Builds a pricing summary struct for the checkout order.

  Delegates to [Pricing.build/1](`Harbor.Checkout.Pricing.build/1`) and returns
  a `%Harbor.Checkout.Pricing{}` with itemized totals ready for rendering.
  """
  defdelegate build_pricing(order), to: Pricing, as: :build

  def submit_checkout(%Session{} = session) do
    session
    |> reload_session()
    |> do_submit_checkout()
  end

  defp do_submit_checkout(%Session{status: :completed} = session) do
    session = Repo.preload(session, [:order])
    {:ok, session.order}
  end

  defp do_submit_checkout(%Session{} = session) do
    Repo.transact(fn ->
      with {:ok, session} <- complete_session(session),
           {:ok, session} <- update_tax_calculation(session) do
        submit_order(session)
      end
    end)
  end

  defp complete_session(%Session{} = session) do
    session
    |> Session.complete_changeset()
    |> Repo.update()
  end

  defp submit_order(%Session{order: order}) do
    pricing = Pricing.build(order)

    attrs = %{
      status: :pending,
      email: order.customer.email,
      subtotal: pricing.subtotal,
      tax: pricing.tax,
      shipping_price: pricing.shipping_price
    }

    order
    |> Order.submit_changeset(attrs, Scope.for_system())
    |> Repo.update()
  end

  @doc """
  Returns the order with the tax calculation preloaded. If the order contents
  have changed, it downloads the tax calculation from the provider, then
  persists it. If the order items and values are unchanged since the last
  calculation, it preloads the last saved calculation.
  """
  def update_tax_calculation(%Session{} = session) do
    session = reload_session(session)
    request = tax_request_from_session(session)

    bin = :erlang.term_to_binary(%{order_id: session.order_id, request: request})
    hash = Base.encode16(:crypto.hash(:sha256, bin), case: :lower)

    case Repo.get_by(Calculation, order_id: session.order_id, hash: hash) do
      nil ->
        idempotency_key = "#{session.order_id},#{hash}"

        with {:ok, response} <- Tax.calculate_taxes(request, idempotency_key) do
          Repo.transact(fn ->
            with {:ok, calculation} <-
                   Tax.create_calculation(%{
                     provider_ref: response.id,
                     order_id: session.order_id,
                     amount: response.amount,
                     hash: hash
                   }),
                 {:ok, _order} <-
                   Orders.update_order(Scope.for_system(), session.order, %{
                     tax: response.amount
                   }) do
              line_items =
                for line_item <- response.line_items do
                  %{
                    provider_ref: line_item.id,
                    amount: line_item.amount,
                    order_item_id: line_item.reference,
                    calculation_id: calculation.id
                  }
                end

              :ok = Tax.upsert_calculation_line_items(line_items)
              session = reload_session(session)
              {:ok, %{session | current_tax_calculation: calculation}}
            end
          end)
        end

      calculation ->
        {:ok, _order} =
          Orders.update_order(Scope.for_system(), session.order, %{tax: calculation.amount})

        session = reload_session(session)
        {:ok, %{session | current_tax_calculation: calculation}}
    end
  end

  defp tax_request_from_session(%Session{order: %Order{} = order}) do
    line_items =
      order.items
      |> Enum.map(&line_item_from_pricing/1)
      |> Enum.sort_by(& &1.reference)

    %Request{
      shipping_price: shipping_price_for_order(order),
      customer_details: build_customer_details(order.shipping_address),
      line_items: line_items
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

  defp shipping_price_for_order(%Order{} = order) do
    case order.delivery_method do
      %DeliveryMethod{price: price} -> price
      _ -> 0
    end
  end

  @spec line_item_from_pricing(OrderItem.t()) :: Request.line_item()
  defp line_item_from_pricing(item) do
    %{
      price: item.price,
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
