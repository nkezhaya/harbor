defmodule Harbor.QueryMacros do
  @moduledoc """
  Exports some additional macros to make Ecto queries a bit nicer.
  """

  defmacro now do
    quote do
      fragment("now()")
    end
  end
end
