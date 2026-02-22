defmodule Harbor.Cache do
  @moduledoc """
  Key-based cache behaviour used by Harbor internals.

  The default implementation backs the cache with an ETS table. Host
  applications can swap in their own implementation (Redis, Cachex, etc.)
  via configuration:

      config :harbor, :cache, MyApp.HarborCache

  ## Callbacks

  Implementations must define `get/1`, `put/2`, and `delete/1`.
  """

  @callback get(key :: term()) :: term() | nil
  @callback put(key :: term(), value :: term()) :: term()
  @callback delete(key :: term()) :: :ok

  def get(key), do: impl().get(key)
  def put(key, value), do: impl().put(key, value)
  def delete(key), do: impl().delete(key)

  defp impl, do: Application.get_env(:harbor, :cache, Harbor.Cache.ETS)
end
