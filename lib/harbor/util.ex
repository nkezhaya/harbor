defmodule Harbor.Util do
  @moduledoc """
  Convenience helpers that keep formatting logic consistent across the app.
  """

  @doc """
  Converts a byte count into a human readable string.

  ## Examples

      iex> Harbor.Util.format_bytes(0)
      "0B"

      iex> Harbor.Util.format_bytes(2_621_440)
      "2.50MB"

  """
  @units [
    {1_024 * 1_024 * 1_024 * 1_024, "TB"},
    {1_024 * 1_024 * 1_024, "GB"},
    {1_024 * 1_024, "MB"},
    {1_024, "KB"}
  ]

  @spec format_bytes(non_neg_integer()) :: String.t()
  def format_bytes(bytes) when is_integer(bytes) and bytes >= 0 do
    case Enum.find(@units, fn {limit, _} -> bytes >= limit end) do
      nil ->
        "#{bytes}B"

      {divisor, unit} ->
        bin = :erlang.float_to_binary(bytes / divisor, decimals: 2)
        bin <> unit
    end
  end
end
