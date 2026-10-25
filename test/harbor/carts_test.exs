defmodule Harbor.CartsTest do
  use Harbor.DataCase, async: true

  import Harbor.{CartsFixtures, CatalogFixtures, CustomersFixtures}

  alias Harbor.Accounts.Scope
  alias Harbor.Carts
  alias Harbor.Carts.{Cart, CartItem}

  setup do
    scope = guest_scope_fixture(customer: false)
    cart = cart_fixture(scope)
    variant = variant_fixture()
    cart_item = cart_item_fixture(cart, %{variant_id: variant.id})

    [scope: scope, cart: cart, cart_item: cart_item, variant: variant]
  end

  describe "get_cart!/2" do
    test "returns the cart with given id", %{scope: scope, cart: cart} do
      assert Carts.get_cart!(scope, cart.id) == cart
    end
  end

  describe "create_cart/2" do
    test "with a guest scope creates a cart" do
      scope = guest_scope_fixture(customer: false)
      assert {:ok, %Cart{} = cart} = Carts.create_cart(scope, %{})
      assert cart.session_token == scope.session_token
      assert cart.status == :active
    end

    test "with a customer scope associates the customer" do
      scope = guest_scope_fixture()
      assert {:ok, %Cart{} = cart} = Carts.create_cart(scope, %{})
      assert cart.customer_id == scope.customer.id
      assert cart.status == :active
    end

    test "raises when the scope cannot own a cart" do
      scope = Scope.for_guest()

      assert_raise Harbor.UnauthorizedError, fn ->
        Carts.create_cart(scope, %{})
      end
    end
  end

  describe "update_cart/3" do
    test "enforces scope ownership when updating", %{scope: scope, cart: cart} do
      update_attrs = %{session_token: "some updated session_token"}
      assert {:ok, %Cart{} = updated_cart} = Carts.update_cart(scope, cart, update_attrs)
      assert updated_cart.session_token == scope.session_token
      assert updated_cart.status == :active
    end

    test "raises when updating a cart for another scope", %{cart: cart} do
      other_scope = guest_scope_fixture(customer: false)

      assert_raise Harbor.UnauthorizedError, fn ->
        Carts.update_cart(other_scope, cart, %{})
      end
    end
  end

  describe "delete_cart/2" do
    test "deletes the cart", %{scope: scope, cart: cart} do
      assert {:ok, %Cart{}} = Carts.delete_cart(scope, cart)
      assert_raise Ecto.NoResultsError, fn -> Carts.get_cart!(scope, cart.id) end
    end

    test "raises when deleting a cart for another scope", %{cart: cart} do
      other_scope = guest_scope_fixture(customer: false)

      assert_raise Harbor.UnauthorizedError, fn ->
        Carts.delete_cart(other_scope, cart)
      end
    end
  end

  describe "change_cart/2" do
    test "returns a cart changeset", %{scope: scope, cart: cart} do
      assert %Ecto.Changeset{} = Carts.change_cart(scope, cart)
    end

    test "raises when requesting a cart changeset for another scope", %{cart: cart} do
      other_scope = guest_scope_fixture(customer: false)

      assert_raise Harbor.UnauthorizedError, fn ->
        Carts.change_cart(other_scope, cart)
      end
    end
  end

  describe "fetch_or_create_active_cart/2" do
    test "returns the existing active cart for the scope", %{scope: scope, cart: cart} do
      assert %Cart{id: cart_id} = Carts.fetch_or_create_active_cart(scope)
      assert cart_id == cart.id
    end

    test "creates a new cart when none exists" do
      scope = guest_scope_fixture(customer: false)

      assert %Cart{} = cart = Carts.fetch_or_create_active_cart(scope)
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
      active_cart = Carts.fetch_active_cart_with_items(scope)
      assert active_cart.id == cart.id

      cart_item_id = cart_item.id
      assert [%CartItem{id: ^cart_item_id, variant: variant}] = active_cart.items
      assert Ecto.assoc_loaded?(variant.product)
    end

    test "returns nil when the scope has no cart" do
      scope = guest_scope_fixture(customer: false)
      refute Carts.fetch_active_cart_with_items(scope)
    end

    test "supports scopes associated to a customer" do
      scope = guest_scope_fixture()
      %Cart{id: cart_id} = cart_fixture(scope)

      assert %Cart{id: ^cart_id} = Carts.fetch_active_cart_with_items(scope)
    end
  end

  describe "get_cart_item!/2" do
    test "returns the cart_item with given id", %{scope: scope, cart_item: cart_item} do
      fetched = Carts.get_cart_item!(scope, cart_item.id)

      assert fetched.id == cart_item.id
    end
  end

  describe "create_cart_item/2" do
    test "with valid data creates a cart_item", %{cart: cart} do
      variant = variant_fixture()
      valid_attrs = %{variant_id: variant.id}
      assert {:ok, %CartItem{} = cart_item} = Carts.create_cart_item(cart, valid_attrs)
      assert cart_item.quantity == 1
      assert cart_item.variant_id == variant.id
    end

    test "rejects the master variant for an optioned product", %{cart: cart} do
      product = product_with_options_fixture([{"Size", ["S"]}])

      assert {:error, changeset} =
               Carts.create_cart_item(cart, %{variant_id: product.master_variant.id})

      assert errors_on(changeset).variant_id == ["is no longer available"]
    end

    test "with invalid data returns error changeset", %{cart: cart} do
      assert {:error, %Ecto.Changeset{}} = Carts.create_cart_item(cart, %{quantity: nil})
    end
  end

  describe "add_item_to_cart/2" do
    test "creates a cart and adds the requested variant when none exists" do
      scope = guest_scope_fixture(customer: false)
      variant = variant_fixture()

      assert {:ok, %CartItem{} = cart_item} =
               Carts.add_item_to_cart(scope, %{"variant_id" => variant.id})

      cart = Carts.fetch_or_create_active_cart(scope)
      assert cart_item.cart_id == cart.id
      assert cart_item.variant_id == variant.id
      assert cart_item.quantity == 1
      assert cart.last_touched_at
      assert cart.expires_at
    end

    test "rejects the master variant for an optioned product" do
      scope = guest_scope_fixture(customer: false)
      product = product_with_options_fixture([{"Size", ["S"]}])

      assert {:error, changeset} =
               Carts.add_item_to_cart(scope, %{"variant_id" => product.master_variant.id})

      assert errors_on(changeset).variant_id == ["is no longer available"]
    end

    test "increments the quantity when the variant already exists", %{
      scope: scope,
      cart_item: cart_item
    } do
      assert {:ok, %CartItem{} = updated_item} =
               Carts.add_item_to_cart(scope, %{"variant_id" => cart_item.variant_id})

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
               Carts.update_cart_item(scope, cart_item, update_attrs)

      assert cart_item.quantity == 43
    end

    test "allows updating a cart item whose variant was later disabled" do
      scope = guest_scope_fixture(customer: false)
      cart = cart_fixture(scope)
      product = product_with_options_fixture([{"Size", ["S", "M"]}])
      variant = Enum.find(product.variants, & &1.enabled)
      cart_item = cart_item_fixture(cart, %{variant_id: variant.id})

      variant
      |> Harbor.Catalog.Variant.changeset(%{enabled: false})
      |> Repo.update!()

      assert {:ok, %CartItem{} = cart_item} =
               Carts.update_cart_item(scope, cart_item, %{quantity: 2})

      assert cart_item.quantity == 2
    end

    test "with invalid data returns error changeset", %{scope: scope, cart_item: cart_item} do
      assert {:error, %Ecto.Changeset{}} =
               Carts.update_cart_item(scope, cart_item, %{quantity: nil})

      assert Carts.get_cart_item!(scope, cart_item.id).quantity == cart_item.quantity
    end
  end

  describe "delete_cart_item/2" do
    test "deletes the cart_item", %{scope: scope, cart_item: cart_item} do
      assert {:ok, %CartItem{}} = Carts.delete_cart_item(scope, cart_item)
      assert_raise Ecto.NoResultsError, fn -> Carts.get_cart_item!(scope, cart_item.id) end
    end
  end

  describe "change_cart_item/1" do
    test "returns a cart_item changeset", %{cart_item: cart_item} do
      assert %Ecto.Changeset{} = Carts.change_cart_item(cart_item)
    end
  end
end
