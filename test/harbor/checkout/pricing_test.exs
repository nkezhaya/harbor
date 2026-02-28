defmodule Harbor.Checkout.PricingTest do
  use Harbor.DataCase, async: true

  import Harbor.{CatalogFixtures, OrdersFixtures, ShippingFixtures}

  alias Harbor.Accounts.Scope
  alias Harbor.Checkout.Pricing
  alias Harbor.{Repo, Settings}

  defp order_with_items(items, order_attrs \\ %{}) do
    scope = Scope.for_system()

    item_attrs =
      Enum.map(items, fn {variant, quantity} ->
        %{variant_id: variant.id, quantity: quantity, price: variant.price}
      end)

    order = order_fixture(scope, Map.put(order_attrs, :items, item_attrs))
    Repo.preload(order, [:delivery_method, :shipping_address, items: []])
  end

  describe "build/1" do
    test "computes count and subtotal from items" do
      variant =
        variant_fixture(%{
          variants: [
            %{
              price: Money.new(:USD, 25),
              enabled: true,
              inventory_policy: :not_tracked,
              quantity_available: 0
            }
          ]
        })

      order = order_with_items([{variant, 3}])
      pricing = Pricing.build(order)

      assert pricing.count == 3
      assert Money.equal?(pricing.subtotal, Money.new(:USD, 75))
    end

    test "sums multiple items" do
      v1 =
        variant_fixture(%{
          variants: [
            %{
              price: Money.new(:USD, 10),
              enabled: true,
              inventory_policy: :not_tracked,
              quantity_available: 0
            }
          ]
        })

      v2 =
        variant_fixture(%{
          variants: [
            %{
              price: Money.new(:USD, "7.50"),
              enabled: true,
              inventory_policy: :not_tracked,
              quantity_available: 0
            }
          ]
        })

      order = order_with_items([{v1, 2}, {v2, 4}])
      pricing = Pricing.build(order)

      assert pricing.count == 6
      assert Money.equal?(pricing.subtotal, Money.new(:USD, 50))
    end

    test "includes shipping price from delivery method" do
      Settings.update(%{delivery_enabled: true})

      variant = variant_fixture()
      delivery_method = delivery_method_fixture(%{price: Money.new(:USD, "5.99")})

      order = order_with_items([{variant, 1}], %{delivery_method_id: delivery_method.id})
      pricing = Pricing.build(order)

      assert Money.equal?(pricing.shipping_price, Money.new(:USD, "5.99"))
    end

    test "shipping is zero when delivery is disabled" do
      Settings.update(%{delivery_enabled: false})

      variant = variant_fixture()
      delivery_method = delivery_method_fixture(%{price: Money.new(:USD, "5.99")})

      order = order_with_items([{variant, 1}], %{delivery_method_id: delivery_method.id})
      pricing = Pricing.build(order)

      assert Money.equal?(pricing.shipping_price, Money.zero(:USD))
    end

    test "shipping is zero when no delivery method is set" do
      variant = variant_fixture()
      order = order_with_items([{variant, 1}])
      pricing = Pricing.build(order)

      assert Money.equal?(pricing.shipping_price, Money.zero(:USD))
    end

    test "carries over tax from order" do
      variant = variant_fixture()
      order = order_with_items([{variant, 1}], %{tax: Money.new(:USD, "3.20")})
      pricing = Pricing.build(order)

      assert Money.equal?(pricing.tax, Money.new(:USD, "3.20"))
    end

    test "tax is nil when order has no tax" do
      variant = variant_fixture()
      order = order_with_items([{variant, 1}], %{tax: Money.new(:USD, 0)})
      pricing = Pricing.build(order)

      assert Money.equal?(pricing.tax, Money.zero(:USD))
    end

    test "total sums subtotal, shipping, and tax" do
      Settings.update(%{delivery_enabled: true})

      variant =
        variant_fixture(%{
          variants: [
            %{
              price: Money.new(:USD, 20),
              enabled: true,
              inventory_policy: :not_tracked,
              quantity_available: 0
            }
          ]
        })

      delivery_method = delivery_method_fixture(%{price: Money.new(:USD, 5)})

      order =
        order_with_items([{variant, 2}], %{
          delivery_method_id: delivery_method.id,
          tax: Money.new(:USD, "3.50")
        })

      pricing = Pricing.build(order)

      # 20*2 + 5 + 3.50 = 48.50
      assert Money.equal?(pricing.total_price, Money.new(:USD, "48.50"))
    end

    test "total treats nil tax as zero" do
      variant =
        variant_fixture(%{
          variants: [
            %{
              price: Money.new(:USD, 10),
              enabled: true,
              inventory_policy: :not_tracked,
              quantity_available: 0
            }
          ]
        })

      order = order_with_items([{variant, 1}])

      # Force nil tax by updating directly
      order = %{order | tax: nil}
      pricing = Pricing.build(order)

      assert Money.equal?(pricing.total_price, Money.new(:USD, 10))
    end

    test "normalizes items with correct line totals" do
      variant =
        variant_fixture(%{
          variants: [
            %{
              price: Money.new(:USD, "12.50"),
              enabled: true,
              inventory_policy: :not_tracked,
              quantity_available: 0
            }
          ]
        })

      order = order_with_items([{variant, 4}])
      pricing = Pricing.build(order)

      assert [item] = pricing.items
      assert item.quantity == 4
      assert Money.equal?(item.price, Money.new(:USD, "12.50"))
      assert Money.equal?(item.total_price, Money.new(:USD, 50))
    end
  end
end
