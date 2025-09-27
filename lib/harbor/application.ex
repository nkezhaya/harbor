defmodule Harbor.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      HarborWeb.Telemetry,
      Harbor.Repo,
      {DNSCluster, query: Application.get_env(:harbor, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:harbor, Oban)},
      {Phoenix.PubSub, name: Harbor.PubSub},
      HarborWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Harbor.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    HarborWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
