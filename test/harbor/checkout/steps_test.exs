defmodule Harbor.Checkout.StepsTest do
  use Harbor.DataCase, async: true

  import Harbor.{CatalogFixtures, CustomersFixtures, OrdersFixtures}

  alias Harbor.Accounts.Scope
  alias Harbor.Checkout.{Pricing, Steps}
  alias Harbor.{Repo, Settings}

  describe "checkout_steps/3 with delivery disabled" do
    setup do
      Settings.update(%{delivery_enabled: false})
      :ok
    end

    test "includes :shipping for physical products" do
      order = order_with_variant()

      steps =
        Steps.checkout_steps(guest_scope_fixture(customer: false), order, %Pricing{
          total_price: Money.new(:USD, 10)
        })

      assert :shipping in steps
    end

    test "excludes :delivery" do
      order = order_with_variant()

      steps =
        Steps.checkout_steps(guest_scope_fixture(customer: false), order, %Pricing{
          total_price: Money.new(:USD, 10)
        })

      refute :delivery in steps
    end
  end

  describe "checkout_steps/3 with payments disabled" do
    setup do
      Settings.update(%{payments_enabled: false})
      :ok
    end

    test "excludes :payment even when total > 0" do
      order = order_with_variant(%{physical_product: false})

      steps =
        Steps.checkout_steps(guest_scope_fixture(customer: false), order, %Pricing{
          total_price: Money.new(:USD, 10)
        })

      refute :payment in steps
    end
  end

  describe "checkout_steps/3 with defaults (all enabled)" do
    test "includes :shipping and :delivery for physical products" do
      order = order_with_variant()

      steps =
        Steps.checkout_steps(guest_scope_fixture(customer: false), order, %Pricing{
          total_price: Money.new(:USD, 10)
        })

      assert :shipping in steps
      assert :delivery in steps
    end

    test "includes :payment when total > 0" do
      order = order_with_variant(%{physical_product: false})

      steps =
        Steps.checkout_steps(guest_scope_fixture(customer: false), order, %Pricing{
          total_price: Money.new(:USD, 10)
        })

      assert :payment in steps
    end

    test "excludes :payment when total is 0" do
      order = order_with_variant(%{physical_product: false})

      steps =
        Steps.checkout_steps(guest_scope_fixture(customer: false), order, %Pricing{
          total_price: Money.new(:USD, 0)
        })

      refute :payment in steps
    end

    test "always ends with :review" do
      order = order_with_variant(%{physical_product: false})

      steps =
        Steps.checkout_steps(guest_scope_fixture(customer: false), order, %Pricing{
          total_price: Money.new(:USD, 0)
        })

      assert List.last(steps) == :review
    end
  end

  defp order_with_variant(product_attrs \\ %{}) do
    scope = Scope.for_system()
    variant = variant_fixture(product_attrs)

    order =
      order_fixture(scope, %{
        items: [%{variant_id: variant.id, quantity: 1, price: variant.price}]
      })

    Repo.preload(order, items: [variant: [:product]])
  end
end
