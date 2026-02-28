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
end
