defmodule Harbor.Mailer do
  @moduledoc false

  def deliver(email) do
    impl().deliver(email)
  end

  defp impl, do: Application.fetch_env!(:harbor, :mailer)
end
