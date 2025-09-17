defmodule Harbor.Shipping.DeliveryMethod do
  @moduledoc """
  Ecto schema for delivery/shipping methods.
  """
  use Harbor.Schema

  @type t() :: %__MODULE__{}

  schema "delivery_methods" do
    field :name, :string
    field :price, :integer

    timestamps()
  end

  @doc false
  def changeset(delivery_method, attrs) do
    delivery_method
    |> cast(attrs, [:name, :price])
    |> validate_required([:name, :price])
    |> unique_constraint(:name)
  end
end
