defmodule Harbor.Checkout.Steps do
  @moduledoc false
  import Harbor.Authorization

  alias Harbor.Accounts.Scope
  alias Harbor.Checkout.{EnsurePaymentSetupWorker, Pricing, Session}
  alias Harbor.Customers.{Address, Customer}
  alias Harbor.Orders.Order
  alias Harbor.{Checkout, Customers, Orders, Repo}

  @spec complete_contact_step(Scope.t(), Session.t(), map()) ::
          {:ok, Session.t(), Scope.t()} | {:error, Ecto.Changeset.t()} | {:error, term()}
  def complete_contact_step(%Scope{} = scope, %Session{} = session, params) do
    session = Repo.preload(session, order: [:cart])

    Repo.transact(fn ->
      order = session.order

      with {:ok, customer} <- Customers.save_customer_profile(scope, params),
           {:ok, _cart} <-
             Checkout.update_cart(Scope.for_system(), order.cart, %{customer_id: customer.id}),
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
      {:ok, {session, scope}} -> {:ok, Checkout.reload_session(session), scope}
      error -> error
    end
  end

  defp enqueue_payment_setup(customer_id, checkout_session_id) do
    %{"customer_id" => customer_id, "checkout_session_id" => checkout_session_id}
    |> EnsurePaymentSetupWorker.new()
    |> Oban.insert()
  end

  @spec complete_shipping_step(Scope.t(), Session.t(), map()) ::
          {:ok, Session.t()} | {:error, Ecto.Changeset.t()} | {:error, term()}
  def complete_shipping_step(%Scope{} = scope, %Session{} = session, params) do
    session = Repo.preload(session, order: [:cart, :shipping_address])
    ensure_authorized!(scope, session.order.cart)

    Repo.transact(fn ->
      with {:ok, address} <- upsert_shipping_address(scope, session.order, params),
           {:ok, _order} <-
             Orders.update_order(scope, session.order, %{shipping_address_id: address.id}) do
        {:ok, Checkout.reload_session(session)}
      end
    end)
  end

  defp upsert_shipping_address(%Scope{} = scope, %Order{} = order, params) do
    case order.shipping_address do
      %Address{} = address -> Customers.update_address(scope, address, params)
      _ -> Customers.create_address(scope, params)
    end
  end

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

  def ensure_valid_current_step!(%Scope{} = scope, %Session{} = session, [first | _] = steps) do
    validated_step =
      cond do
        session.current_step not in steps ->
          first

        session.current_step == first ->
          first

        true ->
          case Enum.find(steps, &(not did_complete?(session, &1))) do
            nil -> List.last(steps)
            incomplete_step -> incomplete_step
          end
      end

    case Checkout.update_session(scope, session, %{current_step: validated_step}) do
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

  defp did_complete?(%Session{} = session, :shipping) do
    case session.order.shipping_address do
      %Address{} -> true
      _ -> false
    end
  end

  defp did_complete?(_session, _step), do: false
end
