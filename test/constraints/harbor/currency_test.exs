defmodule Harbor.Constraints.CurrencyTest do
  use Harbor.DataCase, async: true

  import Harbor.OrdersFixtures

  alias Harbor.Accounts.Scope
  alias Harbor.Orders.Order
  alias Harbor.TestRepo

  test "order totals must use the same currency" do
    order = order_fixture(Scope.for_system())

    error =
      assert_raise Postgrex.Error, fn ->
        Order
        |> where([order], order.id == ^order.id)
        |> TestRepo.update_all(set: [tax: Money.new(:EUR, 1)])
      end

    assert error.postgres.constraint == "totals_same_currency"
  end
end
