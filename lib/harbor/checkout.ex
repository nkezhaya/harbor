defmodule Harbor.Checkout do
  @moduledoc """
  The Checkout context.
  """
  import Ecto.Query, warn: false

  alias Harbor.Accounts.Address
  alias Harbor.Repo
  alias Harbor.Checkout.{Cart, CartItem, Pricing, Session}
  alias Harbor.Orders
  alias Harbor.Orders.Order
  alias Harbor.Shipping.DeliveryMethod

  ## Carts

  def get_cart!(id) do
    Repo.get!(Cart, id)
  end

  def create_cart(attrs) do
    %Cart{}
    |> Cart.changeset(attrs)
    |> Repo.insert()
  end

  def update_cart(%Cart{} = cart, attrs) do
    cart
    |> Cart.changeset(attrs)
    |> Repo.update()
  end

  def delete_cart(%Cart{} = cart) do
    Repo.delete(cart)
  end

  def change_cart(%Cart{} = cart, attrs \\ %{}) do
    Cart.changeset(cart, attrs)
  end

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

  def complete_session(%Session{} = session) do
    session
    |> Repo.reload!()
    |> Repo.preload([
      :billing_address,
      :shipping_address,
      :delivery_method,
      cart: [items: [:variant], user: []]
    ])
    |> do_complete_session()
  end

  defp do_complete_session(%Session{order_id: nil} = session) do
    with :ok <- ensure_active(session),
         :ok <- ensure_not_expired(session),
         {:ok, email} <- resolve_email(session),
         {:ok, address} <- resolve_address(session),
         {:ok, delivery_method} <- resolve_delivery_method(session) do
      order_item_attrs =
        Enum.map(session.cart.items, fn %{variant: variant, quantity: quantity} ->
          %{
            variant_id: variant.id,
            quantity: quantity,
            price: variant.price
          }
        end)

      summary = Pricing.get_summary(session)

      order_attrs = %{
        email: email,
        user_id: session.cart.user && session.cart.user.id,
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
        subtotal: summary.subtotal,
        tax: summary.tax || 0,
        shipping_price: summary.shipping_price
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

      session.cart && session.cart.user && is_binary(session.cart.user.email) ->
        {:ok, session.cart.user.email}

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
end
