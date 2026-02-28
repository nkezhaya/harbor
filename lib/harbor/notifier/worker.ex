defmodule Harbor.Notifier.Worker do
  @moduledoc false
  use Oban.Worker, queue: :notifier

  alias Harbor.Accounts.Scope
  alias Harbor.{Config, Orders}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event" => "order_confirmed", "order_id" => order_id}}) do
    order = Orders.get_order!(Scope.for_system(), order_id)

    Config.notifier().order_confirmed(order)
  end
end
