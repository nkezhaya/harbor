defmodule Harbor.Migration do
  @moduledoc false

  use Ecto.Migration

  @latest_version 1

  def up(opts \\ []) do
    target = Keyword.get(opts, :version, @latest_version)
    migrated = current_version()

    if target > migrated do
      change(migrated + 1, target, :up)
      record_version(target)
    end
  end

  def down(opts \\ []) do
    target = Keyword.get(opts, :version, 0)
    migrated = current_version()

    if migrated > target do
      change(migrated, target + 1, :down)
      record_version(target)
    end
  end

  def latest_version, do: @latest_version

  def current_version do
    result =
      repo().query!("""
      SELECT pg_catalog.obj_description(c.oid, 'pg_class')
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE c.relname = 'settings'
        AND n.nspname = 'public'
      """)

    case result.rows do
      [[comment]] when is_binary(comment) -> String.to_integer(comment)
      _ -> 0
    end
  end

  defp change(from, to, direction) do
    step = if direction == :up, do: 1, else: -1
    range = Range.new(from, to, step)

    for version <- range do
      padded = String.pad_leading(Integer.to_string(version), 2, "0")
      mod = Module.safe_concat(Harbor.Migration, "V#{padded}")
      apply(mod, direction, [])
    end
  end

  defp record_version(version) do
    execute "COMMENT ON TABLE settings IS '#{version}'"
  end
end
