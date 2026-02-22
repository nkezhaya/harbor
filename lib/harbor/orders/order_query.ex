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

  @spec new(Scope.t(), map()) :: t()
  def new(%Scope{} = scope, params \\ %{}) do
    %__MODULE__{}
    |> cast(params, __MODULE__.__schema__(:fields))
    |> apply_scope(scope)
    |> apply_changes()
  end

  defp apply_scope(changeset, scope) do
    cond do
      admin?(scope) ->
        changeset

      scope.customer && scope.customer.id ->
        put_change(changeset, :customer_id, scope.customer.id)

      true ->
        put_change(changeset, :customer_id, nil)
    end
  end

  @spec apply(Ecto.Queryable.t(), t()) :: Ecto.Query.t()
  def apply(queryable, %__MODULE__{} = query) do
    queryable
    |> filter_by_status(query.status)
    |> filter_by_customer(query.customer_id)
    |> order_by(desc: :inserted_at)
  end

  defp filter_by_status(q, nil), do: q
  defp filter_by_status(q, status), do: where(q, [o], o.status == ^status)

  defp filter_by_customer(q, nil), do: q
  defp filter_by_customer(q, customer_id), do: where(q, [o], o.customer_id == ^customer_id)
end
