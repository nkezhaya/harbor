defmodule Harbor.Notifier do
  @moduledoc """
  Behaviour for handling notifications triggered by Harbor lifecycle events.

  Harbor does not ship with a default notifier implementation. To receive
  notifications (e.g. order confirmation emails), configure a module that
  implements this behaviour:

      config :harbor, :notifier, MyApp.HarborNotifier

  The notifier is called asynchronously via an Oban worker, so it will never
  block the originating request. Each callback receives a fully preloaded
  struct.

  When no notifier is configured, notifications are silently skipped.
  """

  alias Harbor.Config
  alias Harbor.Notifier.Worker
  alias Harbor.Orders.Order

  @doc """
  Called when an order is confirmed (transitions to `:pending` at checkout).
  """
  @callback order_confirmed(order :: Order.t()) :: :ok | {:error, term()}

  @doc """
  Enqueues an `order_confirmed` notification for the given order.
  """
  def enqueue_order_confirmed(%Order{id: order_id}) do
    if Config.notifier() do
      %{event: "order_confirmed", order_id: order_id}
      |> Worker.new()
      |> Harbor.Oban.insert()
    else
      :ok
    end
  end
end
