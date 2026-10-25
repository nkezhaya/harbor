defmodule Harbor.CheckoutTest do
  use Harbor.DataCase, async: true

  import Mox
  import Harbor.CatalogFixtures

  import Harbor.{
    AccountsFixtures,
    CartsFixtures,
    CustomersFixtures,
    ShippingFixtures
  }

  alias Harbor.Accounts.Scope
  alias Harbor.{Billing, Carts, Checkout, Currency, Settings}
  alias Harbor.Carts.Cart
  alias Harbor.Checkout.{EnsurePaymentIntentWorker, Session}
  alias Harbor.Orders.Order

  setup do
    scope = guest_scope_fixture(customer: false)
    cart = cart_fixture(scope)
    variant = variant_fixture()
    cart_item = cart_item_fixture(cart, %{variant_id: variant.id})

    [scope: scope, cart: cart, cart_item: cart_item, variant: variant]
  end

  describe "create_session/2" do
    test "creates a draft order and active session", %{
      scope: scope,
      cart: cart,
      cart_item: cart_item,
      variant: variant
    } do
      {:ok, session} = Checkout.create_session(scope, cart)

      assert %Session{status: :active, order_id: order_id} = session
      assert order_id
      assert session.expires_at

      order = Repo.get!(Order, order_id) |> Repo.preload(:items)
      assert order.cart_id == cart.id
      assert order.status == :draft

      assert [%{variant_id: variant_id, quantity: quantity, price: price}] = order.items
      assert variant_id == variant.id
      assert quantity == cart_item.quantity
      assert price == variant.price
    end

    test "rejects carts with disabled variants" do
      scope = guest_scope_fixture(customer: false)
      cart = cart_fixture(scope)
      product = product_with_options_fixture([{"Size", ["S", "M"]}], %{name: "Shirt"})
      variant = Enum.find(product.variants, & &1.enabled)

      cart_item_fixture(cart, %{variant_id: variant.id})

      variant
      |> Harbor.Catalog.Variant.changeset(%{enabled: false})
      |> Repo.update!()

      assert {:error, changeset} = Checkout.create_session(scope, cart)

      assert errors_on(changeset).base == [
               "#{product.name} is no longer available"
             ]
    end

    test "adds errors for all disabled variants in the cart" do
      scope = guest_scope_fixture(customer: false)
      cart = cart_fixture(scope)
      shirt = variant_fixture(name: "shirt")
      hat = variant_fixture(name: "hat")

      cart_item_fixture(cart, %{variant_id: shirt.id})
      cart_item_fixture(cart, %{variant_id: hat.id})

      shirt
      |> Harbor.Catalog.Variant.changeset(%{enabled: false})
      |> Repo.update!()

      hat
      |> Harbor.Catalog.Variant.changeset(%{enabled: false})
      |> Repo.update!()

      assert {:error, changeset} = Checkout.create_session(scope, cart)

      errors = errors_on(changeset).base
      assert [_, _] = errors
      assert "shirt is no longer available" in errors
      assert "hat is no longer available" in errors
    end

    test "creates a new session per checkout", %{scope: scope, cart: cart} do
      {:ok, session} = Checkout.create_session(scope, cart)
      {:ok, other_session} = Checkout.create_session(scope, cart)

      refute session.id == other_session.id
      refute session.order_id == other_session.order_id
    end
  end

  describe "update_session/3" do
    test "updates the session when the scope owns the order cart" do
      scope = guest_scope_fixture()
      cart = cart_fixture(scope)
      {:ok, session} = Checkout.create_session(scope, cart)

      assert {:ok, updated} = Checkout.update_session(scope, session, %{current_step: :review})

      assert updated.current_step == :review
      assert updated.order.cart_id == cart.id
    end

    test "rejects stale session updates", %{cart: cart, scope: scope} do
      {:ok, session} = Checkout.create_session(scope, cart)

      assert {:ok, _updated} = Checkout.update_session(scope, session, %{current_step: :review})

      assert_raise Ecto.StaleEntryError, fn ->
        Checkout.update_session(scope, session, %{current_step: :contact})
      end

      assert Repo.get!(Session, session.id).current_step == :review
    end

    test "raises when the scope does not own the order cart", %{cart: cart, scope: scope} do
      {:ok, session} = Checkout.create_session(scope, cart)
      other_scope = guest_scope_fixture(customer: false)

      assert_raise Harbor.UnauthorizedError, fn ->
        Checkout.update_session(other_scope, session, %{status: :completed})
      end
    end
  end

  describe "complete_contact_step/3" do
    test "saves the customer, enqueues payment profile setup, and returns updated scope and session" do
      scope = guest_scope_fixture(customer: false)
      cart = cart_fixture(scope)
      {:ok, session} = Checkout.create_session(scope, cart)

      params = %{
        "email" => "contact@example.com",
        "first_name" => "Jane",
        "last_name" => "Doe",
        "phone" => "555-0100"
      }

      assert {:ok, session, updated_scope} =
               Checkout.complete_contact_step(scope, session, params)

      assert updated_scope.customer.email == "contact@example.com"
      assert session.id

      assert_enqueued(
        worker: EnsurePaymentIntentWorker,
        args: %{
          "customer_id" => updated_scope.customer.id,
          "checkout_session_id" => session.id
        }
      )
    end

    test "returns a changeset when validation fails" do
      scope = guest_scope_fixture(customer: false)
      cart = cart_fixture(scope)
      {:ok, session} = Checkout.create_session(scope, cart)

      assert {:error, %Ecto.Changeset{}} =
               Checkout.complete_contact_step(scope, session, %{"email" => nil})

      refute_enqueued(worker: EnsurePaymentIntentWorker)
    end
  end

  describe "complete_shipping_step/3" do
    test "creates a shipping address and attaches it to the order" do
      scope = guest_scope_fixture()
      cart = cart_fixture(scope)
      {:ok, session} = Checkout.create_session(scope, cart)

      params = %{
        "first_name" => "Jane",
        "last_name" => "Doe",
        "line1" => "1 Main St",
        "line2" => "Unit 2",
        "city" => "Portland",
        "region" => "OR",
        "postal_code" => "97205",
        "country" => "US",
        "phone" => "555-0100"
      }

      assert {:ok, session} = Checkout.complete_shipping_step(scope, session, params)

      assert %Harbor.Customers.Address{} = session.order.shipping_address
      assert session.order.shipping_address_id == session.order.shipping_address.id
      assert session.order.shipping_address.first_name == "Jane"
      assert session.order.shipping_address.last_name == "Doe"
      assert session.order.shipping_address.customer_id == scope.customer.id
    end

    test "updates the existing shipping address when present" do
      scope = guest_scope_fixture()
      cart = cart_fixture(scope)
      {:ok, session} = Checkout.create_session(scope, cart)

      address =
        address_fixture(scope, %{
          first_name: "Old",
          last_name: "Name",
          line1: "Old Street",
          city: "Old City",
          region: "OR",
          postal_code: "97205",
          country: "US",
          phone: "555-0000"
        })

      {:ok, _order} =
        Harbor.Orders.update_order(scope, session.order, %{shipping_address_id: address.id})

      {:ok, session} = Checkout.get_session(scope, session.id)

      params = %{
        "first_name" => "New",
        "last_name" => "Name",
        "line1" => "New Street",
        "city" => "New City",
        "region" => "OR",
        "postal_code" => "97205",
        "country" => "US",
        "phone" => "555-1111"
      }

      assert {:ok, session} = Checkout.complete_shipping_step(scope, session, params)

      assert session.order.shipping_address_id == address.id
      assert session.order.shipping_address.first_name == "New"
      assert session.order.shipping_address.last_name == "Name"
      assert length(Harbor.Customers.list_addresses(scope)) == 1
    end

    test "returns a changeset when validation fails" do
      scope = guest_scope_fixture()
      cart = cart_fixture(scope)
      {:ok, session} = Checkout.create_session(scope, cart)

      assert {:error, %Ecto.Changeset{}} =
               Checkout.complete_shipping_step(scope, session, %{
                 "first_name" => nil,
                 "last_name" => "Doe"
               })

      order = Repo.get!(Order, session.order.id)
      assert is_nil(order.shipping_address_id)
      assert Harbor.Customers.list_addresses(scope) == []
    end
  end

  describe "complete_delivery_step/3" do
    test "persists the selected delivery method on the order" do
      user = user_fixture()
      scope = Scope.for_user(user)
      customer_fixture(scope, %{email: user.email})
      scope = Scope.for_user(user)
      cart = cart_fixture(scope)
      variant = variant_fixture()
      cart_item_fixture(cart, %{variant_id: variant.id})
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

      {:ok, _order} =
        Harbor.Orders.update_order(scope, session.order, %{shipping_address_id: address.id})

      {:ok, session} = Checkout.get_session(scope, session.id)
      delivery_method = delivery_method_fixture(%{price: Money.new(:USD, 15)})

      assert {:ok, session} =
               Checkout.complete_delivery_step(scope, session, %{
                 "delivery_method_id" => delivery_method.id
               })

      assert session.order.delivery_method_id == delivery_method.id
      assert session.order.delivery_method.id == delivery_method.id

      assert Money.equal?(
               Checkout.build_pricing(session.order).shipping_price,
               delivery_method.price
             )
    end

    test "returns a changeset when no delivery method is selected" do
      user = user_fixture()
      scope = Scope.for_user(user)
      customer_fixture(scope, %{email: user.email})
      scope = Scope.for_user(user)
      cart = cart_fixture(scope)
      variant = variant_fixture()
      cart_item_fixture(cart, %{variant_id: variant.id})
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

      {:ok, _order} =
        Harbor.Orders.update_order(scope, session.order, %{shipping_address_id: address.id})

      {:ok, session} = Checkout.get_session(scope, session.id)
      delivery_method_fixture()

      assert {:error, changeset} = Checkout.complete_delivery_step(scope, session, %{})
      assert errors_on(changeset).delivery_method_id == ["can't be blank"]
      refute Repo.get!(Order, session.order.id).delivery_method_id
    end

    test "rejects delivery selection when delivery is not part of the checkout steps" do
      user = user_fixture()
      scope = Scope.for_user(user)
      customer_fixture(scope, %{email: user.email})
      scope = Scope.for_user(user)
      cart = cart_fixture(scope)
      variant = variant_fixture(%{physical_product: false})
      cart_item_fixture(cart, %{variant_id: variant.id})
      {:ok, session} = Checkout.create_session(scope, cart)
      delivery_method = delivery_method_fixture()

      assert {:error, changeset} =
               Checkout.complete_delivery_step(scope, session, %{
                 "delivery_method_id" => delivery_method.id
               })

      assert errors_on(changeset).base == ["Delivery is not available for this checkout."]
      refute Repo.get!(Order, session.order.id).delivery_method_id
    end

    test "rejects delivery selection when delivery is disabled" do
      Settings.update(Scope.for_system(), %{delivery_enabled: false})

      user = user_fixture()
      scope = Scope.for_user(user)
      customer_fixture(scope, %{email: user.email})
      scope = Scope.for_user(user)
      cart = cart_fixture(scope)
      variant = variant_fixture()
      cart_item_fixture(cart, %{variant_id: variant.id})
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

      {:ok, _order} =
        Harbor.Orders.update_order(scope, session.order, %{shipping_address_id: address.id})

      {:ok, session} = Checkout.get_session(scope, session.id)
      delivery_method = delivery_method_fixture()

      assert {:error, changeset} =
               Checkout.complete_delivery_step(scope, session, %{
                 "delivery_method_id" => delivery_method.id
               })

      assert errors_on(changeset).base == ["Delivery is not available for this checkout."]
      refute Repo.get!(Order, session.order.id).delivery_method_id
    end

    test "rejects delivery selection until earlier steps are complete" do
      user = user_fixture()
      scope = Scope.for_user(user)
      customer_fixture(scope, %{email: user.email})
      scope = Scope.for_user(user)
      cart = cart_fixture(scope)
      variant = variant_fixture()
      cart_item_fixture(cart, %{variant_id: variant.id})
      {:ok, session} = Checkout.create_session(scope, cart)
      delivery_method = delivery_method_fixture()

      assert {:error, changeset} =
               Checkout.complete_delivery_step(scope, session, %{
                 "delivery_method_id" => delivery_method.id
               })

      assert errors_on(changeset).base == [
               "Complete the previous checkout steps before selecting a delivery method."
             ]

      refute Repo.get!(Order, session.order.id).delivery_method_id
    end

    test "returns a validation error when the selected delivery method was deleted" do
      user = user_fixture()
      scope = Scope.for_user(user)
      customer_fixture(scope, %{email: user.email})
      scope = Scope.for_user(user)
      cart = cart_fixture(scope)
      variant = variant_fixture()
      cart_item_fixture(cart, %{variant_id: variant.id})
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

      {:ok, _order} =
        Harbor.Orders.update_order(scope, session.order, %{shipping_address_id: address.id})

      {:ok, session} = Checkout.get_session(scope, session.id)
      delivery_method = delivery_method_fixture()
      assert {:ok, _delivery_method} = Harbor.Shipping.delete_delivery_method(delivery_method)

      assert {:error, changeset} =
               Checkout.complete_delivery_step(scope, session, %{
                 "delivery_method_id" => delivery_method.id
               })

      assert errors_on(changeset).delivery_method_id == ["does not exist"]
      refute Repo.get!(Order, session.order.id).delivery_method_id
    end
  end

  describe "checkout_steps/3" do
    test "includes contact, shipping, and payment when required", %{scope: scope, cart: cart} do
      variant = variant_fixture()
      cart_item_fixture(cart, %{variant_id: variant.id})
      {:ok, session} = Checkout.create_session(scope, cart)
      pricing = Checkout.build_pricing(session.order)

      assert Checkout.checkout_steps(scope, session.order, pricing) ==
               [:contact, :shipping, :delivery, :payment, :review]
    end

    test "omits delivery and payment when not required" do
      scope = user_scope_fixture()
      cart = cart_fixture(scope)

      variant =
        variant_fixture(%{
          physical_product: false,
          variants: [
            %{
              sku: "sku-#{System.unique_integer()}",
              price: Money.new(:USD, 0),
              inventory_policy: :track_strict,
              quantity_available: 10,
              enabled: true
            }
          ]
        })

      cart_item_fixture(cart, %{variant_id: variant.id})
      {:ok, session} = Checkout.create_session(scope, cart)
      pricing = Checkout.build_pricing(session.order)

      assert Checkout.checkout_steps(scope, session.order, pricing) == [:review]
    end
  end

  describe "ensure_valid_current_step!/3" do
    test "rewinds to the first incomplete step and persists it", %{scope: scope, cart: cart} do
      variant = variant_fixture()
      cart_item_fixture(cart, %{variant_id: variant.id})
      {:ok, session} = Checkout.create_session(scope, cart)
      pricing = Checkout.build_pricing(session.order)
      steps = Checkout.checkout_steps(scope, session.order, pricing)
      {:ok, session} = Checkout.update_session(scope, session, %{current_step: :review})

      updated = Checkout.ensure_valid_current_step!(scope, session, steps)

      assert updated.current_step == :contact
      assert Repo.get!(Session, session.id).current_step == :contact
    end

    test "treats delivery as complete once a delivery method is selected" do
      user = user_fixture()
      scope = Scope.for_user(user)
      customer_fixture(scope, %{email: user.email})
      scope = Scope.for_user(user)
      cart = cart_fixture(scope)
      variant = variant_fixture()
      cart_item_fixture(cart, %{variant_id: variant.id})
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

      delivery_method = delivery_method_fixture(%{price: Money.new(:USD, 15)})

      {:ok, _order} =
        Harbor.Orders.update_order(scope, session.order, %{
          shipping_address_id: address.id,
          delivery_method_id: delivery_method.id
        })

      {:ok, session} = Checkout.get_session(scope, session.id)
      pricing = Checkout.build_pricing(session.order)
      steps = Checkout.checkout_steps(scope, session.order, pricing)
      {:ok, session} = Checkout.update_session(scope, session, %{current_step: :review})

      updated = Checkout.ensure_valid_current_step!(scope, session, steps)

      assert updated.current_step == :payment
      assert Repo.get!(Session, session.id).current_step == :payment
    end
  end

  describe "submit_checkout/2" do
    test "requires a shipping address for physical products when address collection is enabled" do
      Settings.update(Scope.for_system(), %{
        address_enabled: true,
        delivery_enabled: false,
        payments_enabled: false,
        tax_enabled: false
      })

      scope = user_scope_fixture()
      cart = cart_fixture(scope)
      variant = variant_fixture()
      cart_item_fixture(cart, %{variant_id: variant.id})
      {:ok, session} = Checkout.create_session(scope, cart)

      assert {:error, changeset} = Checkout.submit_checkout(scope, session)
      assert errors_on(changeset).shipping_address_id == ["can't be blank"]
      assert Repo.get!(Session, session.id).status == :active
      assert Repo.get!(Cart, cart.id).status == :active
    end

    test "submits a physical order without delivery, payment, or tax integrations" do
      Settings.update(Scope.for_system(), %{
        address_enabled: true,
        delivery_enabled: false,
        payments_enabled: false,
        tax_enabled: false
      })

      scope = guest_scope_fixture(customer: false)
      cart = cart_fixture(scope)
      variant = variant_fixture()
      cart_item_fixture(cart, %{variant_id: variant.id, quantity: 2})
      {:ok, session} = Checkout.create_session(scope, cart)

      assert {:ok, session, scope} =
               Checkout.complete_contact_step(scope, session, %{"email" => "buyer@example.com"})

      refute_enqueued(worker: EnsurePaymentIntentWorker)

      assert {:ok, session} =
               Checkout.complete_shipping_step(scope, session, %{
                 "first_name" => "Jane",
                 "last_name" => "Doe",
                 "line1" => "1 Main St",
                 "city" => "Portland",
                 "region" => "OR",
                 "postal_code" => "97205",
                 "country" => "US",
                 "phone" => "555-0100"
               })

      assert {:ok, order} = Checkout.submit_checkout(scope, session)

      assert order.status == :pending
      assert order.email == "buyer@example.com"
      assert order.address_name == "Jane Doe"
      assert order.address_line1 == "1 Main St"
      assert order.address_city == "Portland"
      assert order.address_region == "OR"
      assert order.address_postal_code == "97205"
      assert order.address_country == "US"
      assert order.address_phone == "555-0100"
      assert Money.equal?(order.shipping_price, Money.zero(:USD))
      assert Money.equal?(order.tax, Money.zero(:USD))
      refute order.delivery_method_id
      refute Billing.get_payment_profile(scope, scope.customer.id)
      assert Repo.get!(Session, session.id).status == :completed
      assert Repo.get!(Cart, cart.id).status == :checked_out

      new_cart = Carts.fetch_or_create_active_cart(scope)
      assert new_cart.status == :active
      refute new_cart.id == cart.id
    end

    test "does not require a shipping address for nonphysical products" do
      Settings.update(Scope.for_system(), %{
        address_enabled: true,
        delivery_enabled: false,
        payments_enabled: false,
        tax_enabled: false
      })

      scope = user_scope_fixture()
      cart = cart_fixture(scope)
      variant = variant_fixture(%{physical_product: false})
      cart_item_fixture(cart, %{variant_id: variant.id})
      {:ok, session} = Checkout.create_session(scope, cart)

      assert {:ok, order} = Checkout.submit_checkout(scope, session)
      assert order.status == :pending
      refute order.shipping_address_id
    end

    test "updates the order snapshots and completes the session" do
      # Build catalog and cart
      variant = variant_fixture()
      user = user_fixture()
      scope = user_scope_fixture(user)
      cart = cart_fixture(scope)
      cart_item_fixture(cart, %{variant_id: variant.id, quantity: 2})

      # Shipping method
      delivery_method = delivery_method_fixture(%{price: Money.new(:USD, 15)})

      # Addresses (tied to a user scope)

      billing =
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

      shipping =
        address_fixture(scope, %{
          first_name: "Frodo",
          last_name: "Baggins",
          line1: "1 Bagshot Row",
          city: "Hobbiton",
          region: "OR",
          postal_code: "97205",
          country: "US",
          phone: "+1-555-0002"
        })

      # Session that ties everything together
      {:ok, session} = Checkout.create_session(scope, cart)
      order = session.order

      order
      |> Order.changeset(
        %{
          billing_address_id: billing.id,
          shipping_address_id: shipping.id,
          delivery_method_id: delivery_method.id
        },
        scope
      )
      |> Repo.update!()

      # Exercise
      expect(Harbor.Tax.TaxProviderMock, :calculate_taxes, fn request, _key ->
        assert request.currency == Currency.code()
        {:ok, %{id: "taxid", amount: 1000, line_items: []}}
      end)

      assert {:ok, %Order{} = order} = Checkout.submit_checkout(scope, session)

      # Subtotal is variant.price * quantity, tax from provider, total computed in app
      assert order.email == user.email
      assert order.delivery_method_name == delivery_method.name
      assert Money.equal?(order.subtotal, Money.mult!(variant.price, 2))
      assert Money.equal?(order.shipping_price, delivery_method.price)
      assert Money.equal?(order.tax, Money.new(:USD, 10))
      assert order.status == :pending

      expected_total =
        order.subtotal
        |> Money.add!(order.shipping_price)
        |> Money.add!(order.tax)

      assert Money.equal?(order.total_price, expected_total)

      # Order items snapshot
      order = Repo.preload(order, :items)
      assert [item] = order.items
      assert item.variant_id == variant.id
      assert item.quantity == 2
      assert Money.equal?(item.price, variant.price)

      # Session is marked completed and linked to order
      session = Repo.get!(Session, session.id)
      assert session.status == :completed
      assert session.order_id == order.id
    end

    test "rejects checkout when an item variant was disabled after the session was created" do
      user = user_fixture()
      scope = user_scope_fixture(user)
      cart = cart_fixture(scope)
      product = product_with_options_fixture([{"Size", ["S", "M"]}], %{name: "Shirt"})
      variant = Enum.find(product.variants, & &1.enabled)
      cart_item_fixture(cart, %{variant_id: variant.id, quantity: 1})
      delivery_method = delivery_method_fixture(%{price: Money.new(:USD, 1)})

      address =
        address_fixture(scope, %{
          first_name: "Jessie",
          last_name: "Doe",
          line1: "Main St",
          city: "Town",
          region: "OR",
          postal_code: "97205",
          country: "US",
          phone: "555-1010"
        })

      {:ok, session} = Checkout.create_session(scope, cart)
      order = session.order

      order
      |> Order.changeset(
        %{
          billing_address_id: address.id,
          shipping_address_id: address.id,
          delivery_method_id: delivery_method.id
        },
        scope
      )
      |> Repo.update!()

      variant
      |> Harbor.Catalog.Variant.changeset(%{enabled: false})
      |> Repo.update!()

      assert {:error, changeset} = Checkout.submit_checkout(scope, session)

      assert errors_on(changeset).base == [
               "#{product.name} is no longer available"
             ]
    end

    test "is idempotent when called multiple times for the same session" do
      variant = variant_fixture()
      user = user_fixture()
      scope = user_scope_fixture(user)
      cart = cart_fixture(scope)
      cart_item_fixture(cart, %{variant_id: variant.id, quantity: 1})
      delivery_method = delivery_method_fixture(%{price: Money.new(:USD, 1)})

      address =
        address_fixture(scope, %{
          first_name: "Jessie",
          last_name: "Doe",
          line1: "Main St",
          city: "Town",
          region: "OR",
          postal_code: "97205",
          country: "US",
          phone: "555-1010"
        })

      {:ok, session} = Checkout.create_session(scope, cart)
      order = session.order

      order
      |> Order.changeset(
        %{
          billing_address_id: address.id,
          shipping_address_id: address.id,
          delivery_method_id: delivery_method.id
        },
        scope
      )
      |> Repo.update!()

      expect(Harbor.Tax.TaxProviderMock, :calculate_taxes, fn _req, _key ->
        {:ok, %{id: "taxid", amount: 1000, line_items: []}}
      end)

      assert {:ok, order1} = Checkout.submit_checkout(scope, session)
      assert {:ok, order2} = Checkout.submit_checkout(scope, session)
      assert order1.id == order2.id
    end
  end
end
