defmodule Harbor.Currency do
  @moduledoc """
  Defines Harbor's supported store currency and its money boundaries.

  Harbor currently supports USD only. Persisted prices and totals must use
  whole USD cents before they can be sent to payment or tax providers.
  """

  import Ecto.Changeset, only: [validate_change: 3]

  @code :USD
  @minor_unit_exponent -2

  @doc """
  Returns Harbor's supported ISO 4217 currency code.
  """
  @spec code() :: :USD
  def code, do: @code

  @doc """
  Returns a zero amount in Harbor's supported currency.
  """
  @spec zero() :: Money.t()
  def zero, do: %Money{currency: @code, amount: Decimal.new(0)}

  @doc """
  Converts Harbor's currency code to the lowercase form expected by providers.
  """
  @spec provider_code(:USD) :: String.t()
  def provider_code(@code), do: "usd"

  @doc """
  Validates that a changeset field contains USD with no fractional cents.
  """
  @spec validate(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def validate(changeset, field) do
    validate_change(changeset, field, fn
      ^field, %Money{currency: @code} = money ->
        validate_whole_minor_units(field, money)

      ^field, %Money{} ->
        [{field, "must be in USD"}]
    end)
  end

  @doc """
  Converts an exact USD amount to integer minor units.

  Raises `ArgumentError` when given another currency or a fractional cent.
  """
  @spec to_minor_units!(Money.t()) :: integer()
  def to_minor_units!(%Money{currency: @code} = money) do
    {@code, integer, @minor_unit_exponent, remainder} = Money.to_integer_exp(money)

    if Money.zero?(remainder) do
      integer
    else
      raise ArgumentError, "money must use whole USD cents, got: #{inspect(money)}"
    end
  end

  def to_minor_units!(%Money{} = money) do
    raise ArgumentError, "money must be in USD, got: #{inspect(money)}"
  end

  @doc """
  Converts integer USD minor units to a `Money` value.
  """
  @spec from_minor_units(integer()) :: Money.t()
  def from_minor_units(integer) when is_integer(integer) do
    Money.from_integer(integer, @code)
  end

  defp validate_whole_minor_units(field, money) do
    {@code, _integer, @minor_unit_exponent, remainder} = Money.to_integer_exp(money)

    if Money.zero?(remainder) do
      []
    else
      [{field, "must use whole cents"}]
    end
  end
end
