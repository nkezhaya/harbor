defmodule Harbor.Catalog.OptionType do
  @moduledoc """
  Ecto schema for product option types (e.g., size, color).
  """
  use Harbor.Schema

  alias Harbor.Catalog.{OptionValue, Product}

  @type t() :: %__MODULE__{}

  schema "option_types" do
    field :name, :string
    field :position, :integer, default: 0

    belongs_to :product, Product
    has_many :option_values, OptionValue, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(option_type, attrs) do
    option_type
    |> cast(attrs, [:name, :position])
    |> cast_assoc(:option_values)
    |> validate_required([:name, :position])
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint([:product_id, :name])
  end
end
