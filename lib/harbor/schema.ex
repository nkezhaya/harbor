defmodule Harbor.Schema do
  @moduledoc """
  Common Ecto schema defaults and imports used across the app.
  """
  import Ecto.Changeset

  defmacro __using__(_opts) do
    quote do
      use Ecto.Schema
      import Ecto.Changeset
      import Ecto.Query, warn: false
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

  def trim_fields(changeset, fields) when is_list(fields) do
    Enum.reduce(fields, changeset, &trim_fields(&2, &1))
  end

  def trim_fields(changeset, field) when is_atom(field) do
    case get_field(changeset, field) do
      string when is_binary(string) -> put_change(changeset, field, String.trim(string))
      _ -> changeset
    end
  end

  def put_delete_if_set(changeset) do
    case get_change(changeset, :delete) do
      true -> %{changeset | action: :delete}
      _ -> changeset
    end
  end

  def validate_email(changeset) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/,
      message: "must have the @ sign and no spaces"
    )
    |> validate_length(:email, max: 160)
  end
end
