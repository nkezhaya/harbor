defmodule Harbor.CheckoutTest do
  use Harbor.DataCase

  import Mox
  import Harbor.CatalogFixtures
  import Harbor.{AccountsFixtures, CheckoutFixtures, CustomersFixtures, ShippingFixtures}

  alias Harbor.Checkout
  alias Harbor.Checkout.{Cart, CartItem, Session}
  alias Harbor.Orders.Order

  setup do
    cart = cart_fixture()
    variant = variant_fixture()
    cart_item = cart_item_fixture(cart, %{variant_id: variant.id})

    [cart: cart, cart_item: cart_item, variant: variant]
  end

  describe "get_cart!/1" do
    test "returns the cart with given id" do
      cart = cart_fixture()
      assert Checkout.get_cart!(cart.id) == cart
    end
  end

  describe "create_cart/1" do
    test "with valid data creates a cart" do
      valid_attrs = %{session_token: "some session_token"}
      assert {:ok, %Cart{} = cart} = Checkout.create_cart(valid_attrs)
      assert cart.session_token == "some session_token"
    end

    test "with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Checkout.create_cart(%{})
    end
  end

  describe "update_cart/2" do
    test "with valid data updates the cart", %{cart: cart} do
      update_attrs = %{session_token: "some updated session_token"}
      assert {:ok, %Cart{} = cart} = Checkout.update_cart(cart, update_attrs)
      assert cart.session_token == "some updated session_token"
    end

    test "with invalid data returns error changeset", %{cart: cart} do
      assert {:error, %Ecto.Changeset{}} =
               Checkout.update_cart(cart, %{user_id: nil, session_token: nil})

      assert cart == Checkout.get_cart!(cart.id)
    end
  end

  describe "delete_cart/1" do
    test "deletes the cart", %{cart: cart} do
      assert {:ok, %Cart{}} = Checkout.delete_cart(cart)
      assert_raise Ecto.NoResultsError, fn -> Checkout.get_cart!(cart.id) end
    end
  end

  describe "change_cart/1" do
    test "returns a cart changeset", %{cart: cart} do
      assert %Ecto.Changeset{} = Checkout.change_cart(cart)
    end
  end

  describe "get_cart_item!/1" do
    test "returns the cart_item with given id", %{cart_item: cart_item} do
      assert Checkout.get_cart_item!(cart_item.id) == cart_item
    end
  end

  describe "create_cart_item/1" do
    test "with valid data creates a cart_item", %{cart: cart} do
      variant = variant_fixture()
      valid_attrs = %{quantity: 42, variant_id: variant.id}
      assert {:ok, %CartItem{} = cart_item} = Checkout.create_cart_item(cart, valid_attrs)
      assert cart_item.quantity == 42
    end

    test "with invalid data returns error changeset", %{cart: cart} do
      assert {:error, %Ecto.Changeset{}} = Checkout.create_cart_item(cart, %{quantity: nil})
    end
  end

  describe "update_cart_item/2" do
    test "with valid data updates the cart_item", %{cart_item: cart_item} do
      update_attrs = %{quantity: 43}
      assert {:ok, %CartItem{} = cart_item} = Checkout.update_cart_item(cart_item, update_attrs)
      assert cart_item.quantity == 43
    end

    test "with invalid data returns error changeset", %{cart_item: cart_item} do
      assert {:error, %Ecto.Changeset{}} = Checkout.update_cart_item(cart_item, %{quantity: nil})
      assert cart_item == Checkout.get_cart_item!(cart_item.id)
    end
  end

  describe "delete_cart_item/1" do
    test "deletes the cart_item", %{cart_item: cart_item} do
      assert {:ok, %CartItem{}} = Checkout.delete_cart_item(cart_item)
      assert_raise Ecto.NoResultsError, fn -> Checkout.get_cart_item!(cart_item.id) end
    end
  end

  describe "change_cart_item/1" do
    test "returns a cart_item changeset", %{cart_item: cart_item} do
      assert %Ecto.Changeset{} = Checkout.change_cart_item(cart_item)
    end
  end

  describe "complete_session/1" do
    test "creates an order with items, snapshots, and links the session" do
      # Build catalog and cart
      variant = variant_fixture()
      cart = cart_fixture()
      cart_item_fixture(cart, %{variant_id: variant.id, quantity: 2})

      # Shipping method
      delivery_method = delivery_method_fixture(%{price: 1500})

      # Addresses (tied to a user scope)
      user = user_fixture()
      scope = user_scope_fixture(user)
      customer = customer_fixture(scope)
      scope = %{scope | customer: customer}

      billing =
        address_fixture(scope, %{
          name: "Bilbo Baggins",
          line1: "1 Bagshot Row",
          city: "Hobbiton",
          country: "Shire",
          phone: "+1-555-0001"
        })

      shipping =
        address_fixture(scope, %{
          name: "Frodo Baggins",
          line1: "1 Bagshot Row",
          city: "Hobbiton",
          country: "Shire",
          phone: "+1-555-0002"
        })

      # Session that ties everything together
      expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, session} =
        %Session{}
        |> Session.changeset(%{
          cart_id: cart.id,
          status: :active,
          email: "buyer@example.com",
          expires_at: expires_at,
          billing_address_id: billing.id,
          shipping_address_id: shipping.id,
          delivery_method_id: delivery_method.id,
          payment_intent_id: "pi_test_123"
        })
        |> Repo.insert()

      # Exercise
      expect(Harbor.Tax.TaxProviderMock, :calculate_taxes, fn _req, _key ->
        {:ok, %{id: "taxid", amount: 1000, line_items: []}}
      end)

      assert {:ok, %Order{} = order} = Checkout.complete_session(session)

      # Subtotal is variant.price * quantity, tax defaults to 0, total is computed column
      assert order.email == "buyer@example.com"
      assert order.delivery_method_name == delivery_method.name
      assert order.subtotal == variant.price * 2
      assert order.shipping_price == delivery_method.price
      assert order.tax == 1000
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
      scope = guest_scope_fixture()
      variant = variant_fixture()
      cart = cart_fixture()
      cart_item_fixture(cart, %{variant_id: variant.id, quantity: 1})
      delivery_method = delivery_method_fixture(%{price: 100})

      address =
        address_fixture(scope, %{
          name: "Jessie",
          line1: "Main St",
          city: "Town",
          country: "US",
          phone: "555-1010"
        })

      {:ok, session} =
        %Session{}
        |> Session.changeset(%{
          cart_id: cart.id,
          status: :active,
          email: "idempotent@example.com",
          expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
          billing_address_id: address.id,
          shipping_address_id: address.id,
          delivery_method_id: delivery_method.id
        })
        |> Repo.insert()

      expect(Harbor.Tax.TaxProviderMock, :calculate_taxes, fn _req, _key ->
        {:ok, %{id: "taxid", amount: 1000, line_items: []}}
      end)

      assert {:ok, order1} = Checkout.complete_session(session)
      assert {:ok, order2} = Checkout.complete_session(session)
      assert order1.id == order2.id
    end
  end
end
