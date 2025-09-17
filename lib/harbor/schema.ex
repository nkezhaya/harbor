defmodule Harbor.Schema do
  @moduledoc """
  Common Ecto schema defaults and imports used across the app.
  """
  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset

      Module.put_attribute(__MODULE__, :primary_key, {:id, :binary_id, autogenerate: true})
      Module.put_attribute(__MODULE__, :foreign_key_type, :binary_id)
      Module.put_attribute(__MODULE__, :timestamps_opts, type: :utc_datetime_usec)
      Module.put_attribute(__MODULE__, :schema_prefix, "public")
    end
  end
end
