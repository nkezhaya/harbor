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
    field :delete, :boolean, default: false, virtual: true

    belongs_to :product, Product
    has_many :values, OptionValue, on_replace: :delete

    timestamps()
  end

  @doc false
  def changeset(option_type, attrs) do
    option_type
    |> cast(attrs, [:name, :position])
    |> cast_assoc(:values)
    |> validate_required([:name, :position])
    |> check_constraint(:position,
      name: :position_gte_zero,
      message: "must be greater than or equal to 0"
    )
    |> unique_constraint([:product_id, :name])
    |> put_new_option_value()
  end

  defp put_new_option_value(changeset) do
    with values when is_list(values) <- get_assoc(changeset, :values),
         value when value != %{} <- List.last(values) do
      put_assoc(changeset, :values, values ++ [%{}])
    else
      _ -> changeset
    end
  end
end
