defmodule Harbor.Application do
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      HarborWeb.Telemetry,
      Harbor.Repo,
      Harbor.Oban,
      {DNSCluster, query: Application.get_env(:harbor, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Harbor.PubSub},
      HarborWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Harbor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl Application
  def config_change(changed, _new, removed) do
    HarborWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
