defmodule HarborWeb.CartLive.ShowTest do
  use HarborWeb.ConnCase

  import Phoenix.LiveViewTest
  import Harbor.{CatalogFixtures, CheckoutFixtures, CustomersFixtures}

  alias Harbor.Checkout.CartItem
  alias Harbor.Util

  setup %{conn: conn} do
    scope = guest_scope_fixture(customer: false)
    conn = init_test_session(conn, %{"guest_session_token" => scope.session_token})

    [conn: conn, scope: scope]
  end

  test "renders cart items and summary totals", %{conn: conn, scope: scope} do
    product_name = "Basic Tee"
    variant = variant_fixture(%{name: product_name})

    cart = cart_fixture(scope)
    cart_item = cart_item_fixture(cart, %{variant_id: variant.id, quantity: 2})

    {:ok, view, _html} = live(conn, ~p"/cart")

    assert has_element?(view, "#cart-item-#{cart_item.id}", product_name)
    assert render(view) =~ Util.formatted_price(variant.price)
    assert render(view) =~ Util.formatted_price(variant.price * cart_item.quantity)
    assert has_element?(view, ~S(a[href="/checkout"]), "Checkout")
    assert render(view) =~ "Shipping estimate"
    assert render(view) =~ "Calculated at checkout"
  end

  test "updates item quantity through the selector", %{conn: conn, scope: scope} do
    variant = variant_fixture()
    cart = cart_fixture(scope)
    cart_item = cart_item_fixture(cart, %{variant_id: variant.id, quantity: 1})

    {:ok, view, _html} = live(conn, ~p"/cart")

    qty_form = element(view, "#cart-item-quantity-#{cart_item.id}")

    render_change(qty_form, %{
      "cart_item" => %{"quantity" => "3"},
      "cart_item_id" => cart_item.id
    })

    assert Repo.get!(CartItem, cart_item.id).quantity == 3
    assert render(view) =~ Util.formatted_price(variant.price * 3)
  end

  test "removes an item from the cart", %{conn: conn, scope: scope} do
    variant = variant_fixture()
    cart = cart_fixture(scope)
    cart_item = cart_item_fixture(cart, %{variant_id: variant.id, quantity: 1})

    {:ok, view, _html} = live(conn, ~p"/cart")

    view
    |> element(~s(button[phx-click="remove_item"][phx-value-cart_item_id="#{cart_item.id}"]))
    |> render_click()

    refute has_element?(view, "#cart-item-#{cart_item.id}")
    refute has_element?(view, "a[href=\"/checkout\"]")
    assert render(view) =~ "Your cart is empty"
  end
end
