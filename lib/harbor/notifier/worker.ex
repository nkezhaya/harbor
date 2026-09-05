defmodule Harbor.Notifier.Worker do
  @moduledoc false
  use Oban.Worker, queue: :notifier

  alias Harbor.Config

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event" => "order_confirmed", "order_id" => order_id}}) do
    Config.notifier().order_confirmed(%{order_id: order_id})
  end
end
