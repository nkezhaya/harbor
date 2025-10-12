defmodule Harbor.UtilTest do
  use ExUnit.Case, async: true

  alias Harbor.Util
  doctest Util

  describe "format_bytes/1" do
    test "returns the value in bytes when smaller than one kilobyte" do
      assert Util.format_bytes(512) == "512B"
    end

    test "formats kilobyte values with two decimals" do
      assert Util.format_bytes(1_536) == "1.50KB"
    end

    test "picks the largest matching unit" do
      assert Util.format_bytes(5 * 1_024 * 1_024 * 1_024) == "5.00GB"
    end
  end

  describe "formatted_price/2" do
    test "formats whole dollars by default" do
      assert Util.formatted_price(500) == "$5"
    end

    test "forces cents when requested" do
      assert Util.formatted_price(500, force_cents: true) == "$5.00"
    end

    test "omits currency formatting when disabled" do
      assert Util.formatted_price(123_456, format_currency: false) == "1234.56"
    end

    test "renders negative values" do
      assert Util.formatted_price(-570) == "-$5.70"
    end

    test "return free when zero_is_free is enabled" do
      assert Util.formatted_price(0, zero_is_free: true) == "Free"
    end

    test "accepts string amounts" do
      assert Util.formatted_price("505") == "$5.05"
    end
  end
end
