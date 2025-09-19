defmodule Harbor.Config do
  @moduledoc """
  Centralizes access to runtime configuration values that the application
  depends on at runtime. Keeping these helpers in one module makes it easy to
  mock or extend configuration lookups while avoiding multiple direct
  `Application.get_env/2` calls.
  """

  def tax_provider do
    {provider, _} = Application.get_env(:harbor, :tax_provider)
    provider
  end
end
