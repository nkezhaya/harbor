defmodule Harbor.Repo do
  @moduledoc """
  Ecto repository wrapping database access.
  """
  use Ecto.Repo,
    otp_app: :harbor,
    adapter: Ecto.Adapters.Postgres
end
