defmodule Harbor.Tax.TaxProvider do
  @moduledoc """
  Behaviour that adapters implement to integrate with specific tax vendors. The
  callbacks cover the lifecycle of a tax calculation, including fetching
  available tax codes, running calculations, and recording or refunding
  transactions.
  """

  alias Harbor.Tax.Request

  @type result(type) :: {:ok, type} | {:error, any()}
  @type tax_code() :: %{provider_ref: String.t(), name: String.t(), description: String.t()}
  @type line_item() :: %{id: String.t(), amount: non_neg_integer(), reference: String.t()}

  @callback list_tax_codes() :: {:ok, [tax_code()]} | {:error, term()}
  def list_tax_codes do
    impl().list_tax_codes()
  end

  @callback calculate_taxes(Request.t(), String.t()) ::
              result(%{id: String.t(), amount: non_neg_integer(), line_items: [line_item()]})
  def calculate_taxes(request, idempotency_key) do
    impl().calculate_taxes(request, idempotency_key)
  end

  @callback record_transaction(params) :: result(%{id: String.t(), line_items: [line_item()]})
            when params: %{
                   calculation: String.t(),
                   reference: String.t()
                 }
  def record_transaction(params) do
    impl().record_transaction(params)
  end

  @callback refund_transaction(params) :: result(map())
            when params: %{
                   optional(:flat_amount) => integer(),
                   optional(:line_items) => [line_item()],
                   optional(:mode) => :full | :partial,
                   optional(:original_transaction) => String.t(),
                   optional(:reference) => String.t(),
                   optional(:shipping_cost) => integer()
                 }
  def refund_transaction(params) do
    impl().refund_transaction(params)
  end

  defp impl do
    {_, module} = Application.get_env(:harbor, :tax_provider)
    module
  end
end
