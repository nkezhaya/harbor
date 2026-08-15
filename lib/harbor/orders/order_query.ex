defmodule Harbor.Orders.OrderQuery do
  @moduledoc """
  Parses raw params into typed filter values for order listings and applies them
  to an order queryable.
  """
  use Harbor.Schema

  import Harbor.Authorization

  @primary_key false
  embedded_schema do
    field :status, Ecto.Enum, values: [:draft, :pending, :paid, :shipped, :delivered, :canceled]

    field :customer_id, :binary_id
  end

  @type t() :: %__MODULE__{}

  @spec new(map()) :: t()
  def new(params) do
    %__MODULE__{}
    |> cast(params, __MODULE__.__schema__(:fields))
    |> apply_changes()
  end

  @spec apply(Ecto.Queryable.t(), t(), Scope.t(), keyword()) :: Ecto.Query.t()
  def apply(queryable, %__MODULE__{} = query, %Scope{} = scope, opts) do
    queryable
    |> filter_by_status(query.status)
    |> filter_by_customer(query.customer_id, scope, opts)
    |> order_by(desc: :inserted_at)
  end

  defp filter_by_status(q, nil), do: q
  defp filter_by_status(q, status), do: where(q, [o], o.status == ^status)

  defp filter_by_customer(q, customer_id, scope, opts) do
    cond do
      admin?(scope) ->
        filter_admin_customer(q, customer_id, opts)

      scope.authenticated? and not is_nil(scope.customer) ->
        where(q, [o], o.customer_id == ^scope.customer.id)

      true ->
        where(q, false)
    end
  end

  defp filter_admin_customer(q, customer_id, opts) do
    case Keyword.fetch(opts, :customer_id) do
      {:ok, nil} -> where(q, false)
      {:ok, customer_id} -> where(q, [o], o.customer_id == ^customer_id)
      :error -> filter_by_customer_id(q, customer_id)
    end
  end

  defp filter_by_customer_id(q, nil), do: q
  defp filter_by_customer_id(q, customer_id), do: where(q, [o], o.customer_id == ^customer_id)
end
