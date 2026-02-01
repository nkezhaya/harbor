defmodule Harbor.CheckoutTest do
  use Harbor.DataCase, async: true

  import Mox
  import Harbor.CatalogFixtures

  import Harbor.{
    AccountsFixtures,
    CheckoutFixtures,
    CustomersFixtures,
    ShippingFixtures
  }

  alias Harbor.Accounts.Scope
  alias Harbor.{Checkout, Repo}
  alias Harbor.Checkout.{Cart, CartItem, EnsurePaymentSetupWorker, Session}
  alias Harbor.Orders.Order

  setup do
    scope = guest_scope_fixture(customer: false)
    cart = cart_fixture(scope)
    variant = variant_fixture()
    cart_item = cart_item_fixture(cart, %{variant_id: variant.id})

    [scope: scope, cart: cart, cart_item: cart_item, variant: variant]
  end

  describe "get_cart!/1" do
    test "returns the cart with given id", %{scope: scope, cart: cart} do
      assert Checkout.get_cart!(scope, cart.id) == cart
    end
  end

  describe "create_cart/1" do
    test "with a guest scope creates a cart" do
      scope = guest_scope_fixture(customer: false)
      assert {:ok, %Cart{} = cart} = Checkout.create_cart(scope, %{})
      assert cart.session_token == scope.session_token
      assert cart.status == :active
    end

    test "with a customer scope associates the customer" do
      scope = guest_scope_fixture()
      assert {:ok, %Cart{} = cart} = Checkout.create_cart(scope, %{})
      assert cart.customer_id == scope.customer.id
      assert cart.status == :active
    end

    test "raises when the scope cannot own a cart" do
      scope = Scope.for_guest()

      assert_raise Harbor.UnauthorizedError, fn ->
        Checkout.create_cart(scope, %{})
      end
    end
  end

  describe "update_cart/2" do
    test "enforces scope ownership when updating", %{scope: scope, cart: cart} do
      update_attrs = %{session_token: "some updated session_token"}
      assert {:ok, %Cart{} = updated_cart} = Checkout.update_cart(scope, cart, update_attrs)
      assert updated_cart.session_token == scope.session_token
      assert updated_cart.status == :active
    end

    test "raises when updating a cart for another scope", %{cart: cart} do
      other_scope = guest_scope_fixture(customer: false)

      assert_raise Harbor.UnauthorizedError, fn ->
        Checkout.update_cart(other_scope, cart, %{})
      end
    end
  end

  describe "delete_cart/1" do
    test "deletes the cart", %{scope: scope, cart: cart} do
      assert {:ok, %Cart{}} = Checkout.delete_cart(scope, cart)
      assert_raise Ecto.NoResultsError, fn -> Checkout.get_cart!(scope, cart.id) end
    end

    test "raises when deleting a cart for another scope", %{cart: cart} do
      other_scope = guest_scope_fixture(customer: false)

      assert_raise Harbor.UnauthorizedError, fn ->
        Checkout.delete_cart(other_scope, cart)
      end
    end
  end

  describe "change_cart/1" do
    test "returns a cart changeset", %{scope: scope, cart: cart} do
      assert %Ecto.Changeset{} = Checkout.change_cart(scope, cart)
    end

    test "raises when requesting a cart changeset for another scope", %{cart: cart} do
      other_scope = guest_scope_fixture(customer: false)

      assert_raise Harbor.UnauthorizedError, fn ->
        Checkout.change_cart(other_scope, cart)
      end
    end
  end

  describe "fetch_or_create_active_cart/2" do
    test "returns the existing active cart for the scope", %{scope: scope, cart: cart} do
      assert %Cart{id: cart_id} = Checkout.fetch_or_create_active_cart(scope)
      assert cart_id == cart.id
    end

    test "creates a new cart when none exists" do
      scope = guest_scope_fixture(customer: false)

      assert %Cart{} = cart = Checkout.fetch_or_create_active_cart(scope)
      assert cart.session_token == scope.session_token
      assert cart.status == :active
    end
  end

  describe "fetch_active_cart_with_items/1" do
    test "returns the latest active cart with preloaded associations", %{
      scope: scope,
      cart: cart,
      cart_item: cart_item
    } do
      active_cart = Checkout.fetch_active_cart_with_items(scope)
      assert active_cart.id == cart.id

      cart_item_id = cart_item.id
      assert [%CartItem{id: ^cart_item_id, variant: variant}] = active_cart.items
      assert Ecto.assoc_loaded?(variant.product)
    end

    test "returns nil when the scope has no cart" do
      scope = guest_scope_fixture(customer: false)
      refute Checkout.fetch_active_cart_with_items(scope)
    end

    test "supports scopes associated to a customer" do
      scope = guest_scope_fixture()
      %Cart{id: cart_id} = cart_fixture(scope)

      assert %Cart{id: ^cart_id} = Checkout.fetch_active_cart_with_items(scope)
    end
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
        worker: EnsurePaymentSetupWorker,
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

      refute_enqueued(worker: EnsurePaymentSetupWorker)
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

  describe "checkout_steps/3" do
    test "includes contact, shipping, and payment when required", %{scope: scope, cart: cart} do
      variant = variant_fixture()
      cart_item_fixture(cart, %{variant_id: variant.id})
      {:ok, session} = Checkout.create_session(scope, cart)
      pricing = Checkout.build_pricing(session.order)

      assert Checkout.checkout_steps(scope, session.order, pricing) ==
               [:contact, :shipping, :delivery, :payment, :review]
    end

    test "omits optional steps when not required" do
      scope = user_scope_fixture()
      cart = cart_fixture(scope)

      variant =
        variant_fixture(%{
          physical_product: false,
          variants: [
            %{
              sku: "sku-#{System.unique_integer()}",
              price: 0,
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
  end

  describe "get_cart_item!/2" do
    test "returns the cart_item with given id", %{scope: scope, cart_item: cart_item} do
      fetched = Checkout.get_cart_item!(scope, cart_item.id)

      assert fetched.id == cart_item.id
    end
  end

  describe "create_cart_item/1" do
    test "with valid data creates a cart_item", %{cart: cart} do
      variant = variant_fixture()
      valid_attrs = %{variant_id: variant.id}
      assert {:ok, %CartItem{} = cart_item} = Checkout.create_cart_item(cart, valid_attrs)
      assert cart_item.quantity == 1
      assert cart_item.variant_id == variant.id
    end

    test "with invalid data returns error changeset", %{cart: cart} do
      assert {:error, %Ecto.Changeset{}} = Checkout.create_cart_item(cart, %{quantity: nil})
    end
  end

  describe "add_item_to_cart/2" do
    test "creates a cart and adds the requested variant when none exists" do
      scope = guest_scope_fixture(customer: false)
      variant = variant_fixture()

      assert {:ok, %CartItem{} = cart_item} =
               Checkout.add_item_to_cart(scope, %{"variant_id" => variant.id})

      cart = Checkout.fetch_or_create_active_cart(scope)
      assert cart_item.cart_id == cart.id
      assert cart_item.variant_id == variant.id
      assert cart_item.quantity == 1
      assert cart.last_touched_at
      assert cart.expires_at
    end

    test "increments the quantity when the variant already exists", %{
      scope: scope,
      cart_item: cart_item
    } do
      assert {:ok, %CartItem{} = updated_item} =
               Checkout.add_item_to_cart(scope, %{"variant_id" => cart_item.variant_id})

      reloaded_item = Repo.get!(CartItem, cart_item.id)
      assert updated_item.id == cart_item.id
      assert reloaded_item.quantity == cart_item.quantity + 1
      assert updated_item.quantity == reloaded_item.quantity
    end
  end

  describe "update_cart_item/3" do
    test "with valid data updates the cart_item", %{scope: scope, cart_item: cart_item} do
      update_attrs = %{quantity: 43}

      assert {:ok, %CartItem{} = cart_item} =
               Checkout.update_cart_item(scope, cart_item, update_attrs)

      assert cart_item.quantity == 43
    end

    test "with invalid data returns error changeset", %{scope: scope, cart_item: cart_item} do
      assert {:error, %Ecto.Changeset{}} =
               Checkout.update_cart_item(scope, cart_item, %{quantity: nil})

      assert Checkout.get_cart_item!(scope, cart_item.id).quantity == cart_item.quantity
    end
  end

  describe "delete_cart_item/2" do
    test "deletes the cart_item", %{scope: scope, cart_item: cart_item} do
      assert {:ok, %CartItem{}} = Checkout.delete_cart_item(scope, cart_item)
      assert_raise Ecto.NoResultsError, fn -> Checkout.get_cart_item!(scope, cart_item.id) end
    end
  end

  describe "change_cart_item/1" do
    test "returns a cart_item changeset", %{cart_item: cart_item} do
      assert %Ecto.Changeset{} = Checkout.change_cart_item(cart_item)
    end
  end

  describe "submit_checkout/2" do
    test "updates the order snapshots and completes the session" do
      # Build catalog and cart
      variant = variant_fixture()
      user = user_fixture()
      scope = user_scope_fixture(user)
      cart = cart_fixture(scope)
      cart_item_fixture(cart, %{variant_id: variant.id, quantity: 2})

      # Shipping method
      delivery_method = delivery_method_fixture(%{price: 1500})

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
      expect(Harbor.Tax.TaxProviderMock, :calculate_taxes, fn _req, _key ->
        {:ok, %{id: "taxid", amount: 1000, line_items: []}}
      end)

      assert {:ok, %Order{} = order} = Checkout.submit_checkout(scope, session)

      # Subtotal is variant.price * quantity, tax defaults to 0, total is computed column
      assert order.email == user.email
      assert order.delivery_method_name == delivery_method.name
      assert order.subtotal == variant.price * 2
      assert order.shipping_price == delivery_method.price
      assert order.tax == 1000
      assert order.status == :pending
      assert order.total_price == order.subtotal + order.shipping_price + order.tax

      # Order items snapshot
      order = Repo.preload(order, :items)
      assert [item] = order.items
      assert item.variant_id == variant.id
      assert item.quantity == 2
      assert item.price == variant.price

      # Session is marked completed and linked to order
      session = Repo.get!(Session, session.id)
      assert session.status == :completed
      assert session.order_id == order.id
    end

    test "is idempotent when called multiple times for the same session" do
      variant = variant_fixture()
      user = user_fixture()
      scope = user_scope_fixture(user)
      cart = cart_fixture(scope)
      cart_item_fixture(cart, %{variant_id: variant.id, quantity: 1})
      delivery_method = delivery_method_fixture(%{price: 100})

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
