defmodule Harbor.Web.CheckoutLive.FormTest do
  use Harbor.ConnCase, async: true

  import Harbor.{CatalogFixtures, CheckoutFixtures, CustomersFixtures, ShippingFixtures}
  import Phoenix.LiveViewTest

  alias Harbor.Accounts.Scope
  alias Harbor.{Checkout, Orders, Repo}
  alias Harbor.Orders.Order

  describe "guest checkout" do
    test "renders checkout without a customer profile", %{conn: conn} do
      scope = guest_scope_fixture(customer: false)
      conn = init_test_session(conn, %{"guest_session_token" => scope.session_token})

      variant = variant_fixture()
      cart = cart_fixture(scope)
      cart_item_fixture(cart, %{variant_id: variant.id, quantity: 1})
      {:ok, session} = Checkout.create_session(scope, cart)

      {:ok, view, _html} = live(conn, "/checkout/#{session.id}")

      assert has_element?(view, "#customer-form")
    end
  end

  describe "user checkout" do
    setup :register_and_log_in_user

    test "selecting a delivery method persists it, updates pricing, and advances the step", %{
      conn: conn,
      user: user
    } do
      {_scope, session, variant} = checkout_session_at_delivery_step(user)

      delivery_method =
        delivery_method_fixture(%{name: "Express delivery", price: Money.new(:USD, 15)})

      {:ok, view, _html} = live(conn, "/checkout/#{session.id}")

      view
      |> form("#delivery-form", %{"delivery" => %{"delivery_method_id" => delivery_method.id}})
      |> render_submit()

      assert Repo.get!(Order, session.order.id).delivery_method_id == delivery_method.id
      assert has_element?(view, "#payment-form")
      assert has_element?(view, "#checkout-delivery-summary", "Express delivery")

      assert has_element?(
               view,
               "#checkout-summary-shipping",
               Money.to_string!(delivery_method.price)
             )

      expected_total = Money.add!(variant.price, delivery_method.price)
      assert has_element?(view, "#checkout-summary-total", Money.to_string!(expected_total))
    end

    test "delivery CTA stays neutral when a paid delivery method adds payment", %{
      conn: conn,
      user: user
    } do
      {_scope, session, _variant} =
        checkout_session_at_delivery_step(user, %{
          master_variant: %{
            sku: "sku-#{System.unique_integer([:positive])}",
            price: Money.new(:USD, 0),
            inventory_policy: :track_strict,
            quantity_available: 10,
            enabled: true
          }
        })

      delivery_method =
        delivery_method_fixture(%{name: "Express delivery", price: Money.new(:USD, 15)})

      {:ok, view, _html} = live(conn, "/checkout/#{session.id}")

      refute has_element?(view, "#checkout-step-payment")
      assert has_element?(view, "#delivery-continue")
      refute has_element?(view, "#delivery-continue", "Continue to review")

      view
      |> form("#delivery-form", %{"delivery" => %{"delivery_method_id" => delivery_method.id}})
      |> render_submit()

      assert Repo.get!(Order, session.order.id).delivery_method_id == delivery_method.id
      assert has_element?(view, "#checkout-step-payment")
      assert has_element?(view, "#payment-form")
    end

    test "missing delivery selection shows an error and does not advance", %{
      conn: conn,
      user: user
    } do
      {_scope, session, _variant} = checkout_session_at_delivery_step(user)
      delivery_method_fixture()

      {:ok, view, _html} = live(conn, "/checkout/#{session.id}")

      view
      |> form("#delivery-form", %{"delivery" => %{}})
      |> render_submit()

      refute Repo.get!(Order, session.order.id).delivery_method_id
      assert has_element?(view, "#delivery-form")
      assert has_element?(view, "#delivery-method-errors p", "can't be blank")
      refute has_element?(view, "#payment-form")
    end
  end

  defp checkout_session_at_delivery_step(user, variant_attrs \\ %{}) do
    scope = Scope.for_user(user)
    customer_fixture(scope, %{email: user.email})
    scope = Scope.for_user(user)
    cart = cart_fixture(scope)
    variant = variant_fixture(variant_attrs)
    cart_item_fixture(cart, %{variant_id: variant.id, quantity: 1})
    {:ok, session} = Checkout.create_session(scope, cart)

    address =
      address_fixture(scope, %{
        first_name: "Jane",
        last_name: "Doe",
        line1: "1 Main St",
        city: "Portland",
        region: "OR",
        postal_code: "97205",
        country: "US",
        phone: "555-0100"
      })

    {:ok, _order} = Orders.update_order(scope, session.order, %{shipping_address_id: address.id})
    {:ok, session} = Checkout.get_session(scope, session.id)
    {:ok, session} = Checkout.update_session(scope, session, %{current_step: :delivery})

    {scope, session, variant}
  end
end
