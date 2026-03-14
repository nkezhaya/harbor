defmodule Credo.Check.Refactor.RedundantIgnoredMatchTest do
  use Credo.Test.Case, async: true

  alias Credo.Check.Refactor.RedundantIgnoredMatch

  test "reports assigning a value to underscore" do
    """
    defmodule Sample do
      def foo do
        _ = String.upcase("hello")
      end
    end
    """
    |> to_source_file()
    |> run_check(RedundantIgnoredMatch)
    |> assert_issue(fn issue ->
      assert issue.line_no == 3
      assert issue.trigger == "_ ="
    end)
  end

  test "reports ignored parameters matched against an additional pattern" do
    """
    defmodule Sample do
      def foo(%Product{} = _product), do: :ok
    end
    """
    |> to_source_file()
    |> run_check(RedundantIgnoredMatch)
    |> assert_issue(fn issue ->
      assert issue.line_no == 2
      assert issue.trigger == "_product"
    end)
  end

  test "reports ignored parameters matched against an additional pattern in guarded definitions" do
    """
    defmodule Sample do
      def foo(%Product{} = _product) when true, do: :ok
    end
    """
    |> to_source_file()
    |> run_check(RedundantIgnoredMatch)
    |> assert_issue(fn issue ->
      assert issue.line_no == 2
      assert issue.trigger == "_product"
    end)
  end

  test "does not report direct expression evaluation" do
    """
    defmodule Sample do
      def foo do
        String.upcase("hello")
      end
    end
    """
    |> to_source_file()
    |> run_check(RedundantIgnoredMatch)
    |> refute_issues()
  end

  test "does not report plain ignored parameters without an extra pattern" do
    """
    defmodule Sample do
      def foo(_product), do: :ok
    end
    """
    |> to_source_file()
    |> run_check(RedundantIgnoredMatch)
    |> refute_issues()
  end

  test "does not report plain pattern-matched parameters without an ignored variable" do
    """
    defmodule Sample do
      def foo(%Product{}), do: :ok
    end
    """
    |> to_source_file()
    |> run_check(RedundantIgnoredMatch)
    |> refute_issues()
  end
end
