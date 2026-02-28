defmodule Harbor.QueryMacros do
  @moduledoc false

  defmacro now do
    quote do
      fragment("now()")
    end
  end

  defmacro money_amount(field) do
    quote do
      fragment("(?).amount", unquote(field))
    end
  end
end
