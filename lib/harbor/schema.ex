defmodule Harbor.Schema do
  @moduledoc """
  Common Ecto schema defaults and imports used across the app.
  """
  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      import unquote(__MODULE__)

      alias Harbor.Accounts.Scope

      Module.put_attribute(
        __MODULE__,
        :primary_key,
        {:id, :binary_id, autogenerate: false, read_after_writes: true}
      )

      Module.put_attribute(__MODULE__, :foreign_key_type, :binary_id)
      Module.put_attribute(__MODULE__, :timestamps_opts, type: :utc_datetime_usec)
      Module.put_attribute(__MODULE__, :schema_prefix, "public")
    end
  end

  def put_delete_if_set(changeset) do
    case Ecto.Changeset.get_change(changeset, :delete) do
      true -> %{changeset | action: :delete}
      _ -> changeset
    end
  end
end
