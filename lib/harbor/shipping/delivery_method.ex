defmodule Harbor.Shipping.DeliveryMethod do
  @moduledoc """
  Ecto schema for delivery/shipping methods.
  """
  use Harbor.Schema

  @type t() :: %__MODULE__{}

  schema "delivery_methods" do
    field :name, :string
    field :price, :integer
    field :fulfillment_type, Ecto.Enum, values: [:ship, :pickup]

    timestamps()
  end

  @doc false
  def changeset(delivery_method, attrs) do
    delivery_method
    |> cast(attrs, [:name, :price, :fulfillment_type])
    |> validate_required([:name, :price, :fulfillment_type])
    |> unique_constraint(:name)
  end
end
