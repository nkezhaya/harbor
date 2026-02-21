defmodule Harbor.Repo do
  @moduledoc """
  Wrappers around `Ecto.Repo` and `Ecto.Adapters.SQL` callbacks.

  Not meant to be called directly. Use your application's repo instead.
  """

  import Ecto.Query, only: [limit: 2, offset: 2]

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

  @doc """
  Paginates a queryable, returning entries with pagination metadata.

  ## Options

    * `:page` - page number (default `1`)
    * `:per_page` - results per page (default `20`)

  ## Return value

      %{entries: [...], page: 1, per_page: 20, total: 42, total_pages: 3}
  """

  @spec paginate(Ecto.Queryable.t(), map() | keyword()) :: %{
          entries: [Ecto.Schema.t() | term()],
          page: pos_integer(),
          per_page: pos_integer(),
          total: non_neg_integer(),
          total_pages: pos_integer()
        }
  def paginate(queryable, %{} = opts) do
    paginate(queryable, Map.to_list(opts))
  end

  def paginate(queryable, opts) when is_list(opts) do
    max_per_page = 100
    per_page = min(opts[:per_page] || 20, max_per_page)
    total = aggregate(queryable, :count)
    total_pages = max(ceil(total / per_page), 1)

    page =
      (opts[:page] || 1)
      |> max(1)
      |> min(total_pages)

    entries =
      queryable
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> all()

    %{entries: entries, page: page, per_page: per_page, total: total, total_pages: total_pages}
  end

  defp impl, do: Harbor.Config.repo()
end
