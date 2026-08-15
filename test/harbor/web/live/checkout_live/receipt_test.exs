defmodule Harbor.Web.CheckoutLive.ReceiptTest do
  use Harbor.ConnCase, async: true

  import Harbor.{CatalogFixtures, CheckoutFixtures, CustomersFixtures, ShippingFixtures}
  import Mox
  import Phoenix.LiveViewTest

  alias Harbor.Accounts.Scope
  alias Harbor.{Checkout, Repo}
  alias Harbor.Checkout.Session
  alias Harbor.Orders.Order

  test "renders receipt details for the owning authenticated customer", %{conn: conn} do
    user = Harbor.AccountsFixtures.user_fixture()
    conn = log_in_user(conn, user)
    scope = Scope.for_user(user)
    customer_fixture(scope, %{email: user.email})
    scope = Scope.for_user(user)

    {session, order} = completed_checkout(scope)

    {:ok, view, _html} = live(conn, "/checkout/#{session.id}/receipt")

    assert has_element?(view, "#checkout-receipt")
    assert has_element?(view, "#receipt-order-number", order.number)
    assert has_element?(view, "#receipt-order-status")
    assert has_element?(view, "#receipt-delivery-method")
    assert has_element?(view, "#receipt-total")

    [item | _] = order.items
    assert has_element?(view, "#receipt-item-#{item.id}")
    assert has_element?(view, "#receipt-shipping-address")
  end

  test "renders the receipt for the owning guest session token", %{conn: conn} do
    scope = guest_scope_fixture(customer: false)
    cart = cart_fixture(scope)
    customer = customer_fixture(scope)
    checkout_scope = Scope.attach_customer(scope, customer)
    {session, order} = completed_checkout(checkout_scope, cart)
    conn = init_test_session(conn, %{"guest_session_token" => scope.session_token})

    {:ok, view, _html} = live(conn, "/checkout/#{session.id}/receipt")

    assert has_element?(view, "#checkout-receipt")
    assert has_element?(view, "#receipt-order-number", order.number)
  end

  test "redirects another customer and an authenticated user without a customer", %{conn: conn} do
    owner = Harbor.AccountsFixtures.user_fixture()
    owner_scope = Scope.for_user(owner)
    customer_fixture(owner_scope, %{email: owner.email})
    owner_scope = Scope.for_user(owner)
    {session, _order} = completed_checkout(owner_scope)

    other_user = Harbor.AccountsFixtures.user_fixture()
    other_scope = Scope.for_user(other_user)
    customer_fixture(other_scope, %{email: other_user.email})

    assert {:error, {:live_redirect, %{to: "/cart"}}} =
             live(log_in_user(conn, other_user), "/checkout/#{session.id}/receipt")

    user_without_customer = Harbor.AccountsFixtures.user_fixture()

    assert {:error, {:live_redirect, %{to: "/cart"}}} =
             live(log_in_user(conn, user_without_customer), "/checkout/#{session.id}/receipt")
  end

  test "redirects a guest hydrated with the same customer but a different token", %{conn: conn} do
    receipt_scope = guest_scope_fixture(customer: false)
    customer = customer_fixture(receipt_scope)
    receipt_scope = Scope.attach_customer(receipt_scope, customer)

    receipt_cart =
      cart_fixture(Scope.for_system(), %{
        customer_id: customer.id,
        session_token: receipt_scope.session_token
      })

    {session, _order} = completed_checkout(receipt_scope, receipt_cart)
    {:ok, _cart} = Checkout.update_cart(Scope.for_system(), receipt_cart, %{status: :merged})

    attacker_scope = guest_scope_fixture(customer: false)

    cart_fixture(Scope.for_system(), %{
      customer_id: customer.id,
      session_token: attacker_scope.session_token
    })

    conn = init_test_session(conn, %{"guest_session_token" => attacker_scope.session_token})

    assert {:error, {:live_redirect, %{to: "/cart"}}} =
             live(conn, "/checkout/#{session.id}/receipt")
  end

  test "redirects to cart when receipt is missing", %{conn: conn} do
    missing_id = Ecto.UUID.generate()

    assert {:error, {:live_redirect, %{to: "/cart"}}} =
             live(conn, "/checkout/#{missing_id}/receipt")
  end

  defp completed_checkout(scope, cart \\ nil) do
    variant = variant_fixture()
    cart = cart || cart_fixture(scope)
    cart_item_fixture(cart, %{variant_id: variant.id, quantity: 2})
    delivery_method = delivery_method_fixture(%{price: Money.new(:USD, 15)})

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
