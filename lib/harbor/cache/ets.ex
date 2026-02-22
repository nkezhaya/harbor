defmodule Harbor.Cache.ETS do
  @moduledoc false

  @behaviour Harbor.Cache

  use GenServer

  @table :harbor_cache

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  @impl Harbor.Cache
  def get(key) do
    case :ets.lookup(@table, key) do
      [{^key, value}] -> value
      [] -> nil
    end
  end

  @impl Harbor.Cache
  def put(key, value) do
    :ets.insert(@table, {key, value})
    value
  end

  @impl Harbor.Cache
  def delete(key) do
    :ets.delete(@table, key)
    :ok
  end
end
