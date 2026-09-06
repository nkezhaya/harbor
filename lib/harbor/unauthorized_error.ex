defmodule Harbor.UnauthorizedError do
  @moduledoc """
  Raised when a scope isn't authorized to access a resource.
  """

  defexception message: "Unauthorized"
end
