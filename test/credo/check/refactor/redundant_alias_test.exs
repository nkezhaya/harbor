defmodule Credo.Check.Refactor.RedundantAliasTest do
  use Credo.Test.Case, async: true

  alias Credo.Check.Refactor.RedundantAlias

  test "reports an alias already introduced by use" do
    """
    defmodule Sample do
      use Harbor.Schema
      alias Harbor.Accounts.Scope
    end
    """
    |> to_source_file()
    |> run_check(RedundantAlias)
    |> assert_issue(fn issue ->
      assert issue.line_no == 3
      assert issue.trigger == "Harbor.Accounts.Scope"
      assert issue.message =~ "use Harbor.Schema"
    end)
  end

  test "reports an alias introduced by a use macro with options" do
    """
    defmodule Sample do
      use Harbor.Web, :component
      alias Harbor.Web.ImageHelpers
    end
    """
    |> to_source_file()
    |> run_check(RedundantAlias)
    |> assert_issue(fn issue ->
      assert issue.line_no == 3
      assert issue.trigger == "Harbor.Web.ImageHelpers"
      assert issue.message =~ "use Harbor.Web"
    end)
  end

  test "reports aliases introduced by nested use macros" do
    """
    defmodule Sample do
      use Harbor.DataCase, async: true
      alias Harbor.Repo
    end
    """
    |> to_source_file()
    |> run_check(RedundantAlias)
    |> assert_issue(fn issue ->
      assert issue.line_no == 3
      assert issue.trigger == "Harbor.Repo"
      assert issue.message =~ "use Harbor.DataCase"
    end)
  end

  test "resolves aliases used as macro names" do
    """
    defmodule Sample do
      alias Harbor.Schema
      use Schema
      alias Harbor.Accounts.Scope
    end
    """
    |> to_source_file()
    |> run_check(RedundantAlias)
    |> assert_issue(fn issue ->
      assert issue.line_no == 4
      assert issue.message =~ "use Harbor.Schema"
    end)
  end

  test "reports only redundant members of a multi-alias" do
    """
    defmodule Sample do
      use Harbor.Schema
      alias Harbor.Accounts.{Scope, User}
    end
    """
    |> to_source_file()
    |> run_check(RedundantAlias)
    |> assert_issue(fn issue ->
      assert issue.line_no == 3
      assert issue.trigger == "Scope"
    end)
  end

  test "handles expanded multi-aliases whose target modules are not loaded" do
    """
    defmodule Sample do
      use Harbor.RedundantAliasMacro
      alias Harbor.RedundantAliasFixtures.First
    end
    """
    |> to_source_file()
    |> run_check(RedundantAlias)
    |> assert_issue(fn issue ->
      assert issue.line_no == 3
      assert issue.trigger == "Harbor.RedundantAliasFixtures.First"
    end)
  end

  test "reports aliases introduced with a custom local name" do
    """
    defmodule Sample do
      use Harbor.RedundantAliasMacro
      alias Harbor.RedundantAliasFixtures.Third, as: ThirdAlias
    end
    """
    |> to_source_file()
    |> run_check(RedundantAlias)
    |> assert_issue(fn issue ->
      assert issue.line_no == 3
      assert issue.message =~ "aliased as ThirdAlias"
    end)
  end

  test "does not report aliases declared before use" do
    """
    defmodule Sample do
      alias Harbor.Accounts.Scope
      use Harbor.Schema
    end
    """
    |> to_source_file()
    |> run_check(RedundantAlias)
    |> refute_issues()
  end

  test "does not report an alias with a different local name" do
    """
    defmodule Sample do
      use Harbor.Schema
      alias Harbor.Accounts.Scope, as: AccountScope
    end
    """
    |> to_source_file()
    |> run_check(RedundantAlias)
    |> refute_issues()
  end

  test "does not report or retain an alias that shadows a macro alias" do
    """
    defmodule Sample do
      use Harbor.Schema
      alias Another.Scope
      alias Harbor.Accounts.Scope
    end
    """
    |> to_source_file()
    |> run_check(RedundantAlias)
    |> refute_issues()
  end

  test "does not report aliases not introduced by use" do
    """
    defmodule Sample do
      use Harbor.Schema
      alias Harbor.Accounts.User
    end
    """
    |> to_source_file()
    |> run_check(RedundantAlias)
    |> refute_issues()
  end

  test "ignores use macros that cannot be expanded" do
    """
    defmodule Sample do
      use NotCompiled
      alias Harbor.Accounts.Scope
    end
    """
    |> to_source_file()
    |> run_check(RedundantAlias)
    |> refute_issues()
  end
end
