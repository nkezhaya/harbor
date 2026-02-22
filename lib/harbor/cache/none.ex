defmodule Harbor.Cache.None do
  # A no-op cache that always misses. Every read falls through to the
  # underlying data source. Useful for testing where cache isolation
  # between concurrent tests is required.

  @moduledoc false

  @behaviour Harbor.Cache

  @impl Harbor.Cache
  def get(_key), do: nil

  @impl Harbor.Cache
  def put(_key, value), do: value

  @impl Harbor.Cache
  def delete(_key), do: :ok
end
