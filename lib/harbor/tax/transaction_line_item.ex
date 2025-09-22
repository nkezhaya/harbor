defmodule Harbor.Tax.TransactionLineItem do
  @moduledoc """
  Persists tax transaction metadata for an order line item so we can track the
  provider reference needed for audits, refunds, or reconciliations.
  """
  use Harbor.Schema

  @type t() :: %__MODULE__{}

  schema "tax_transaction_line_items" do
    field :provider_ref, :string
    field :order_item_id, :binary_id
  end
end
