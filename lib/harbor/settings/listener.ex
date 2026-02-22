defmodule Harbor.Settings.Listener do
  @moduledoc false

  use GenServer

  alias Harbor.{Cache, Config}

  @channel "harbor_settings_changed"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    repo = Config.repo()
    config = repo.config()

    {:ok, pid} = Postgrex.Notifications.start_link(config)

    case Postgrex.Notifications.listen(pid, @channel) do
      {:ok, ref} -> {:ok, %{pid: pid, ref: ref}}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl GenServer
  def handle_info({:notification, _pid, _ref, @channel, _payload}, state) do
    Cache.delete(:settings)
    {:noreply, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end
end
