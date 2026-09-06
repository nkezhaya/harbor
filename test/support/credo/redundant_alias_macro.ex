defmodule Harbor.RedundantAliasMacro do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      alias Harbor.RedundantAliasFixtures.{First, Second}
      # credo:disable-for-next-line Credo.Check.Readability.AliasAs
      alias Harbor.RedundantAliasFixtures.Third, as: ThirdAlias
    end
  end
end
