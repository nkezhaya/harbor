defmodule Harbor.NotifierTest do
  use Harbor.DataCase, async: true

  import Harbor.AccountsFixtures
  import Harbor.OrdersFixtures

  alias Harbor.Notifier

  describe "enqueue_order_confirmed/1" do
    test "enqueues a notification job" do
      scope = user_scope_fixture()
      order = order_fixture(scope)

      assert {:ok, %Oban.Job{}} = Notifier.enqueue_order_confirmed(order)

      assert_enqueued(
        worker: Notifier.Worker,
        args: %{"event" => "order_confirmed", "order_id" => order.id}
      )
    end
  end
end
