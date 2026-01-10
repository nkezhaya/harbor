defmodule Harbor.TaxTest do
  use Harbor.DataCase, async: true

  import Harbor.{CatalogFixtures, CheckoutFixtures, CustomersFixtures, TaxFixtures}

  alias Harbor.{Checkout, Repo, Tax}
  alias Harbor.Tax.Calculation

  describe "list_tax_codes/0" do
    test "returns tax codes" do
      tax_code = tax_code_fixture()
      assert Enum.any?(Tax.list_tax_codes(), &(&1 == tax_code))
    end
  end

  describe "create_calculation/1" do
    setup do
      product = product_fixture()
      variant = List.first(product.variants)
      scope = guest_scope_fixture(customer: false)
      cart = cart_fixture(scope)
      cart_item = cart_item_fixture(cart, %{variant_id: variant.id, quantity: 1})
      {:ok, session} = Checkout.create_session(scope, cart)

      %{session: session, cart_item: cart_item}
    end

    test "returns existing calculation when one already exists", %{session: session} do
      attrs = %{
        provider_ref: "calc_123",
        order_id: session.order_id,
        amount: 1_000,
        hash: "123"
      }

      assert {:ok, first_calc} = Tax.create_calculation(attrs)
      assert {:ok, second_calc} = Tax.create_calculation(attrs)

      assert first_calc.id
      assert first_calc.id == second_calc.id

      assert Repo.aggregate(Calculation, :count, :id) == 1
    end
  end
end
