defmodule Harbor.Application do
  @moduledoc false

  use Application

  alias Harbor.Config

  @impl Application
  def start(_type, _args) do
    Harbor.Config.validate!()

    children = [
      {Phoenix.PubSub, name: Harbor.PubSub},
      Harbor.Settings.Listener
    ]

    children =
      case Config.cache() do
        Harbor.Cache.ETS -> children ++ [Harbor.Cache.ETS]
        _ -> children
      end

    Supervisor.start_link(children, strategy: :one_for_one, name: Harbor.Supervisor)
  end
end
