defmodule Harbor.Tax.Calculation do
  @moduledoc """
  Represents a tax calculation snapshot returned by a provider for a checkout
  order. Stores the provider reference, derived totals, and the hash we use to
  decide if a calculation needs to be refreshed.
  """
  use Harbor.Schema

  alias Harbor.Orders.Order
  alias Harbor.Tax.CalculationLineItem

  @type t() :: %__MODULE__{}

  schema "tax_calculations" do
    field :provider_ref, :string
    field :amount, :integer
    field :hash, :integer

    belongs_to :order, Order

    has_many :line_items, CalculationLineItem

    timestamps()
  end

  def changeset(struct, params) do
    cast(struct, params, [:provider_ref, :amount, :order_id, :hash])
  end
end
