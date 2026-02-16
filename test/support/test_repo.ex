defmodule Harbor.TestRepo do
  use Ecto.Repo, otp_app: :harbor, adapter: Ecto.Adapters.Postgres
end
