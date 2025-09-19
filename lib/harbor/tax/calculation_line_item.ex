defmodule Harbor.Tax.CalculationLineItem do
  use Harbor.Schema

  alias Harbor.Tax.Calculation

  @type t() :: %__MODULE__{}

  schema "tax_calculation_line_items" do
    field :provider_ref, :string
    field :amount, :integer
    field :cart_item_id, :binary_id

    belongs_to :calculation, Calculation
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:provider_ref, :amount, :cart_item_id])
    |> validate_required([:provider_ref, :amount, :cart_item_id])
    |> assoc_constraint(:calculation)
  end
end
