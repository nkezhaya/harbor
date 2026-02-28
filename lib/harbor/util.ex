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

  @doc """
  Generates a random secret.
  """
  def csprng(size \\ 32) do
    Base.url_encode64(:crypto.strong_rand_bytes(size), padding: false)
  end

  @doc """
  Converts a `Money` struct to an integer cent amount.

  ## Examples

      iex> Harbor.Util.money_to_cents(Money.new(:USD, "16.80"))
      1680

  """
  @spec money_to_cents(Money.t()) :: integer()
  def money_to_cents(%Money{} = money) do
    money
    |> Money.to_decimal()
    |> Decimal.mult(100)
    |> Decimal.to_integer()
  end

  @doc """
  Converts an integer cent amount to a `Money` struct.

  ## Examples

      iex> Harbor.Util.cents_to_money(1680)
      Money.new(:USD, "16.8")

  """
  @spec cents_to_money(integer()) :: Money.t()
  def cents_to_money(cents) when is_integer(cents) do
    cents
    |> Decimal.new()
    |> Decimal.div(100)
    |> Money.new(:USD)
  end
end
