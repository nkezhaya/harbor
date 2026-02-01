defmodule HarborWeb.CheckoutLive.ReceiptTest do
  use HarborWeb.ConnCase, async: true

  import Harbor.{CatalogFixtures, CheckoutFixtures, CustomersFixtures, ShippingFixtures}
  import Mox
  import Phoenix.LiveViewTest

  alias Harbor.Accounts.Scope
  alias Harbor.{Checkout, Repo}
  alias Harbor.Checkout.Session
  alias Harbor.Orders.Order

  setup :register_and_log_in_user

  test "renders receipt details for completed checkout", %{conn: conn, user: user} do
    scope = Scope.for_user(user)
    customer_fixture(scope, %{email: user.email})
    scope = Scope.for_user(user)

    {session, order} = completed_checkout(scope)

    {:ok, view, _html} = live(conn, ~p"/checkout/#{session.id}/receipt")

    assert has_element?(view, "#checkout-receipt")
    assert has_element?(view, "#receipt-order-number", order.number)
    assert has_element?(view, "#receipt-order-status")
    assert has_element?(view, "#receipt-delivery-method")
    assert has_element?(view, "#receipt-total")

    [item | _] = order.items
    assert has_element?(view, "#receipt-item-#{item.id}")
    assert has_element?(view, "#receipt-shipping-address")
  end

  test "redirects to cart when receipt is missing", %{conn: conn} do
    missing_id = Ecto.UUID.generate()

    assert {:error, {:live_redirect, %{to: "/cart"}}} =
             live(conn, ~p"/checkout/#{missing_id}/receipt")
  end

  defp completed_checkout(scope) do
    variant = variant_fixture()
    cart = cart_fixture(scope)
    cart_item_fixture(cart, %{variant_id: variant.id, quantity: 2})
    delivery_method = delivery_method_fixture(%{price: 1500})

    address =
      address_fixture(scope, %{
        first_name: "Bilbo",
        last_name: "Baggins",
        line1: "1 Bagshot Row",
        city: "Hobbiton",
        region: "OR",
        postal_code: "97205",
        country: "US",
        phone: "+1-555-0001"
      })

    {:ok, session} = Checkout.create_session(scope, cart)

    session.order
    |> Order.changeset(
      %{shipping_address_id: address.id, delivery_method_id: delivery_method.id},
      scope
    )
    |> Repo.update!()

    expect(Harbor.Tax.TaxProviderMock, :calculate_taxes, fn _req, _key ->
      {:ok, %{id: "taxid", amount: 1000, line_items: []}}
    end)

    assert {:ok, order} = Checkout.submit_checkout(scope, session)

    order = Repo.preload(order, items: [variant: [:product]])
    session = Repo.get!(Session, session.id)

    {session, order}
  end
end
