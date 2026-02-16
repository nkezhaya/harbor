defmodule Harbor.Oban do
  @moduledoc false

  def insert(changeset, opts \\ []) do
    impl().insert(changeset, opts)
  end

  defp impl, do: Application.fetch_env!(:harbor, :oban)
end
