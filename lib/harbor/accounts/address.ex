defmodule Harbor.Accounts.Address do
  @moduledoc """
  Ecto schema for user addresses and related validations.
  """
  use Harbor.Schema
  alias Harbor.Accounts.User

  @type t() :: %__MODULE__{}

  schema "addresses" do
    field :name, :string
    field :line1, :string
    field :line2, :string
    field :city, :string
    field :region, :string
    field :postal_code, :string
    field :country, :string
    field :phone, :string
    field :default, :boolean, default: false

    belongs_to :user, User

    timestamps()
  end

  @doc false
  def changeset(address, attrs) do
    address
    |> cast(attrs, [
      :name,
      :line1,
      :line2,
      :city,
      :region,
      :postal_code,
      :country,
      :phone,
      :default
    ])
    |> validate_required([:name, :line1, :city, :country, :phone])
  end
end
