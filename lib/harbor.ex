defmodule Harbor do
  @moduledoc """
  Open source storefront.
  """

  defmodule UnauthorizedError do
    defexception message: "Unauthorized"
  end
end
