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
  Formats cents as a currency string.

  ## Options

    * `:format_currency` – include the currency symbol and group thousands (default: true)
    * `:force_cents` – always render the decimal portion (default: false)
    * `:zero_is_free` – render zero as `"Free"` (default: false)

  ## Examples

      iex> Harbor.Util.formatted_price(500000)
      "$5,000"

      iex> Harbor.Util.formatted_price(1000, force_cents: true)
      "$10.00"
  """
  @spec formatted_price(String.t() | integer(), keyword()) :: String.t()
  def formatted_price(price, opts \\ [])

  def formatted_price(price, opts) when is_binary(price) do
    price
    |> String.to_integer()
    |> formatted_price(opts)
  end

  def formatted_price(price, opts) when is_integer(price) do
    negative? = price < 0
    cents = abs(price)
    whole_dollars = Integer.floor_div(cents, 100)
    sign_prefix = if negative?, do: "-", else: ""
    format_currency? = Keyword.get(opts, :format_currency, true)
    force_cents? = Keyword.get(opts, :force_cents, nil)
    zero_is_free? = Keyword.get(opts, :zero_is_free, false)

    if cents == 0 and zero_is_free? do
      "Free"
    else
      if format_currency? do
        formatted_dollars = number_to_delimited(whole_dollars)

        "#{sign_prefix}$#{formatted_dollars}"
      else
        "#{sign_prefix}#{whole_dollars}"
      end
      |> append_cents(cents, force_cents?)
    end
  end

  defp number_to_delimited(number) do
    sign_prefix = if number < 0, do: "-", else: ""

    grouped =
      number
      |> abs()
      |> Integer.to_charlist()
      |> Enum.reverse()
      |> Enum.chunk_every(3)
      |> Enum.map(&Enum.reverse/1)
      |> Enum.reverse()
      |> Enum.join(",")

    sign_prefix <> grouped
  end

  defp append_cents(prefix, cents, force_cents?) do
    case rem(cents, 100) do
      0 ->
        if force_cents? do
          "#{prefix}.00"
        else
          prefix
        end

      remaining_cents when remaining_cents < 10 ->
        "#{prefix}.0#{remaining_cents}"

      remaining_cents ->
        "#{prefix}.#{remaining_cents}"
    end
  end
end
