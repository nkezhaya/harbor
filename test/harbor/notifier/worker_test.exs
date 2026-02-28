defmodule Harbor.Notifier.WorkerTest do
  use Harbor.DataCase, async: true

  import Harbor.AccountsFixtures
  import Harbor.OrdersFixtures
  import Mox

  alias Harbor.Notifier.Worker

  setup :set_mox_from_context
  setup :verify_on_exit!

  describe "perform/1" do
    test "calls order_confirmed on the configured notifier" do
      scope = user_scope_fixture()
      order = order_fixture(scope)

      expect(Harbor.NotifierMock, :order_confirmed, fn notified_order ->
        assert notified_order.id == order.id
        :ok
      end)

      assert :ok = perform_job(Worker, %{event: "order_confirmed", order_id: order.id})
    end
  end
end
