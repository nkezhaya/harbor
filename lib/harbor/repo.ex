defmodule Harbor.Repo do
  @moduledoc """
  Wrappers around `Ecto.Repo` and `Ecto.Adapters.SQL` callbacks.

  Not meant to be called directly. Use your application's repo instead.
  """

  @callbacks [
    aggregate: 2,
    all: 1,
    delete: 1,
    delete!: 1,
    delete_all: 1,
    exists?: 1,
    get: 2,
    get!: 2,
    get_by: 2,
    get_by!: 2,
    insert: 1,
    insert!: 1,
    insert_all: 2,
    insert_or_update: 1,
    one: 1,
    one!: 1,
    preload: 2,
    reload!: 1,
    transact: 1,
    transaction: 1,
    update: 1,
    update!: 1,
    update_all: 2
  ]

  for {fun, arity} <- @callbacks do
    args = Macro.generate_arguments(arity, __MODULE__)

    def unquote(fun)(unquote_splicing(args), opts \\ []) do
      impl().unquote(fun)(unquote_splicing(args), opts)
    end
  end

  defp impl, do: Application.fetch_env!(:harbor, :repo)
end
