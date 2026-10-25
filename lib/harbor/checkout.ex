defmodule Harbor.Checkout do
  @moduledoc """
  The Checkout context.
  """
  import Harbor.Authorization

  alias Ecto.Changeset
  alias Harbor.Accounts.Scope
  alias Harbor.Carts
  alias Harbor.Carts.{Cart, CartItem}
  alias Harbor.Checkout.{Pricing, Session, Steps}
  alias Harbor.Currency
  alias Harbor.Customers.Customer
  alias Harbor.{Notifier, Orders, Repo, Tax}
  alias Harbor.Orders.{Order, OrderItem}
  alias Harbor.Settings
  alias Harbor.Shipping.DeliveryMethod
  alias Harbor.Tax.{Calculation, Request}

  ## Sessions

  @doc """
  Creates a checkout session for the cart by creating a draft order.

  The provided [Scope](`Harbor.Accounts.Scope`) is authorized against the cart
  before any work is done. The order is created from the cart items and linked
  to a new active session. The resulting session is preloaded with the
  associations required by pricing and tax calculations.
  """
  @spec create_session(Scope.t(), Cart.t()) ::
          {:ok, Session.t()} | {:error, Changeset.t()}
  def create_session(%Scope{} = scope, %Cart{} = cart) do
    ensure_authorized!(scope, cart)

    cart = Repo.preload(cart, items: [variant: :product])

    Repo.transact(fn ->
      with :ok <- validate_purchasability(cart, scope),
           {:ok, order} <- create_draft_order(cart) do
        session =
          %Session{order_id: order.id}
          |> Session.changeset(%{})
          |> Repo.insert!()

        {:ok, preload_session(session)}
      end
    end)
  end

  defp validate_purchasability(%{items: items} = cart_or_order, scope) do
    changeset =
      Enum.reduce(items, Changeset.change(cart_or_order), fn item, changeset ->
        case purchasability_error(item, scope) do
          nil ->
            changeset

          {message, reason} ->
            Changeset.add_error(changeset, :base, message, item: item, reason: reason)
        end
      end)

    if changeset.valid? do
      :ok
    else
      {:error, changeset}
    end
  end

  defp purchasability_error(item, _scope) do
    if item.variant.enabled do
      nil
    else
      {"#{item.variant.product.name} is no longer available", :disabled}
    end
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

  @doc """
  Fetches a completed checkout session for receipt display.

  Returns `{:ok, session}` when the session is completed and authorized for the
  given scope, otherwise returns `{:error, reason}`.
  """
  @spec get_completed_session(Scope.t(), Ecto.UUID.t()) ::
          {:ok, Session.t()} | {:error, :not_found}
  def get_completed_session(%Scope{} = scope, id) do
    case Repo.get_by(Session, id: id, status: :completed) do
      nil ->
        {:error, :not_found}

      %Session{} = session ->
        session = preload_completed_session(session)

        if receipt_authorized?(scope, session.order.cart) do
          {:ok, session}
        else
          {:error, :not_found}
        end
    end
  end

  defp receipt_authorized?(%Scope{} = scope, %Cart{} = cart) do
    admin?(scope) or receipt_owner?(scope, cart)
  end

  defp receipt_owner?(
         %Scope{
           role: :user,
           authenticated?: true,
           customer: %Customer{id: customer_id}
         },
         %Cart{customer_id: customer_id}
       ) do
    true
  end

  defp receipt_owner?(%Scope{role: :guest, session_token: session_token}, %Cart{
         session_token: session_token
       })
       when is_binary(session_token) do
    true
  end

  defp receipt_owner?(_scope, _cart) do
    false
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

  @doc false
  def reload_session(%Session{} = session) do
    session
    |> Repo.reload!()
    |> preload_session()
  end

  @doc """
  Completes the contact step by saving the customer profile and associating it
  with the cart and order.

  Returns `{:ok, session, scope}` with the updated scope containing the saved
  customer, or `{:error, changeset}` when validation fails.
  """
  @spec complete_contact_step(Scope.t(), Session.t(), map()) ::
          {:ok, Session.t(), Scope.t()} | {:error, Changeset.t()}
  defdelegate complete_contact_step(scope, session, params), to: Steps

  @doc """
  Completes the shipping step by upserting a shipping address for the current
  scope's customer and attaching it to the order.

  Returns `{:ok, session}` with the updated order on success, or
  `{:error, changeset}` when validation fails.
  """
  @spec complete_shipping_step(Scope.t(), Session.t(), map()) ::
          {:ok, Session.t()} | {:error, Changeset.t()}
  defdelegate complete_shipping_step(scope, session, params), to: Steps

  @doc """
  Completes the delivery step by validating the selected delivery method and
  persisting it on the checkout order.

  Returns `{:ok, session}` with the updated order on success, or
  `{:error, changeset}` when validation fails.
  """
  @spec complete_delivery_step(Scope.t(), Session.t(), map()) ::
          {:ok, Session.t()} | {:error, Changeset.t()}
  defdelegate complete_delivery_step(scope, session, params), to: Steps

  @doc """
  Computes the ordered checkout steps for the given scope, order, and pricing.

  - Adds `:contact` when the scope is not authenticated.
  - Adds `:shipping` when address collection is enabled and any order item is physical.
  - Adds `:delivery` when delivery is enabled and any order item is a physical product.
  - Adds `:payment` when payments are enabled and the order total is greater than zero.
  - Always appends `:review` as the final step.
  """
  @spec checkout_steps(Scope.t(), Order.t(), Pricing.t()) :: [atom()]
  defdelegate checkout_steps(scope, order, pricing), to: Steps

  @doc """
  Normalizes the session's `current_step` against the provided steps.

  If the current step is invalid, it is set to the first step. If any prior step
  has not been completed, the current step is rewound to the first incomplete
  step. Expects a non-empty `steps` list and raises when persisting the updated
  step fails.
  """
  defdelegate ensure_valid_current_step!(scope, session, steps), to: Steps

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
            product: [:images, :tax_code, product_type: [:tax_code]]
          ]
        ]
      ]
    )
  end

  defp preload_completed_session(%Session{} = session) do
    Repo.preload(session,
      order: [
        :cart,
        items: [variant: [:option_values, product: [:images]]]
      ]
    )
  end

  @doc """
  Builds a pricing summary struct for the checkout order.

  Delegates to [Pricing.build/1](`Harbor.Checkout.Pricing.build/1`) and returns
  a `%Harbor.Checkout.Pricing{}` with itemized totals ready for rendering.
  """
  defdelegate build_pricing(order), to: Pricing, as: :build

  def submit_checkout(%Scope{} = scope, %Session{} = session) do
    session = reload_session(session)
    ensure_authorized!(scope, session.order.cart)

    if session.status == :completed do
      {:ok, session.order}
    else
      with :ok <- validate_purchasability(session.order, scope) do
        do_submit_checkout(session)
      end
    end
  end

  defp do_submit_checkout(%Session{} = session) do
    changeset =
      Order.submit_changeset(session.order, %{}, Scope.for_system(),
        address_enabled: Settings.address_enabled?()
      )

    with {:ok, _order} <- Changeset.apply_action(changeset, :update),
         {:ok, session} <- update_tax_calculation_if_enabled(session) do
      do_complete_and_submit(session)
    end
  end

  defp update_tax_calculation_if_enabled(%Session{} = session) do
    if Settings.tax_enabled?() do
      update_tax_calculation(session)
    else
      {:ok, session}
    end
  end

  defp do_complete_and_submit(%Session{} = session) do
    result =
      Repo.transact(fn ->
        with {:ok, session} <- complete_session(session),
             {:ok, order} <- submit_order(session),
             {:ok, _cart} <-
               Carts.update_cart(Scope.for_system(), session.order.cart, %{status: :checked_out}) do
          {:ok, order}
        end
      end)

    # Notify outside of the transaction, so failures don't prevent order
    # submission.
    with {:ok, order} <- result do
      Notifier.enqueue_order_confirmed(order)
      result
    end
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
    |> Order.submit_changeset(attrs, Scope.for_system(),
      address_enabled: Settings.address_enabled?()
    )
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
    hash = tax_request_hash(session, request)

    case Repo.get_by(Calculation, order_id: session.order_id, hash: hash) do
      nil -> create_tax_calculation(session, request, hash)
      calculation -> apply_tax_calculation(session, calculation)
    end
  end

  defp tax_request_hash(%Session{} = session, %Request{} = request) do
    bin = :erlang.term_to_binary(%{order_id: session.order_id, request: request})
    Base.encode16(:crypto.hash(:sha256, bin), case: :lower)
  end

  defp create_tax_calculation(%Session{} = session, %Request{} = request, hash) do
    idempotency_key = "#{session.order_id},#{hash}"

    with {:ok, response} <- Tax.calculate_taxes(request, idempotency_key) do
      persist_tax_calculation(session, response, hash)
    end
  end

  defp persist_tax_calculation(%Session{} = session, response, hash) do
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
               tax: Currency.from_minor_units(response.amount)
             }),
           :ok <- upsert_tax_line_items(response, calculation) do
        session = reload_session(session)
        {:ok, %{session | current_tax_calculation: calculation}}
      end
    end)
  end

  defp upsert_tax_line_items(response, calculation) do
    line_items =
      for line_item <- response.line_items do
        %{
          provider_ref: line_item.id,
          amount: line_item.amount,
          order_item_id: line_item.reference,
          calculation_id: calculation.id
        }
      end

    Tax.upsert_calculation_line_items(line_items)
  end

  defp apply_tax_calculation(%Session{} = session, %Calculation{} = calculation) do
    case Orders.update_order(Scope.for_system(), session.order, %{
           tax: Currency.from_minor_units(calculation.amount)
         }) do
      {:ok, _order} ->
        session = reload_session(session)
        {:ok, %{session | current_tax_calculation: calculation}}

      error ->
        error
    end
  end

  defp tax_request_from_session(%Session{order: %Order{} = order}) do
    line_items =
      order.items
      |> Enum.map(&line_item_from_pricing/1)
      |> Enum.sort_by(& &1.reference)

    %Request{
      currency: Currency.code(),
      shipping_price: Currency.to_minor_units!(shipping_price_for_order(order)),
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
    if Settings.delivery_enabled?() do
      case order.delivery_method do
        %DeliveryMethod{price: price} -> price
        _ -> Currency.zero()
      end
    else
      Currency.zero()
    end
  end

  @spec line_item_from_pricing(OrderItem.t()) :: Request.line_item()
  defp line_item_from_pricing(item) do
    %{
      price: Currency.to_minor_units!(item.price),
      quantity: item.quantity,
      reference: item.id,
      tax_code_ref: variant_tax_code_ref(item.variant)
    }
  end

  defp variant_tax_code_ref(variant) do
    tax_code =
      variant.tax_code || variant.product.tax_code || variant.product.product_type.tax_code

    tax_code.provider_ref
  end
end
