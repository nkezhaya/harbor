defmodule Harbor.CurrencyTest do
  use ExUnit.Case, async: true

  alias Harbor.Currency

  test "converts exact USD values to and from minor units" do
    assert Currency.to_minor_units!(Money.new(:USD, "16.80")) == 1680
    assert Money.equal?(Currency.from_minor_units(1680), Money.new(:USD, "16.80"))
  end

  test "rejects fractional cents" do
    assert_raise ArgumentError, ~r/must use whole USD cents/, fn ->
      Currency.to_minor_units!(Money.new(:USD, "16.801"))
    end
  end
end
