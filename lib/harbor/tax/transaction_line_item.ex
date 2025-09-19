defmodule Harbor.Tax.TransactionLineItem do
  use Harbor.Schema

  @type t() :: %__MODULE__{}

  schema "tax_transaction_line_items" do
    field :provider_ref, :string
    field :order_item_id, :binary_id
  end
end
