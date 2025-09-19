defmodule Harbor.Tax.TaxCode do
  @moduledoc """
  Ecto schema for tax code records sourced from an external tax provider. Each
  entry stores descriptive information plus the provider-specific reference that
  downstream integrations require.
  """

  use Harbor.Schema

  alias Harbor.Config

  @type t() :: %__MODULE__{}

  schema "tax_codes" do
    field :name, :string
    field :description, :string
    field :provider, :string
    field :provider_ref, :string
    field :position, :integer, read_after_writes: true
    field :effective_at, :utc_datetime_usec
    field :ended_at, :utc_datetime_usec

    timestamps()
  end

  @doc false
  def changeset(tax_code, attrs) do
    tax_code
    |> cast(attrs, [:name, :description, :provider_ref, :effective_at, :ended_at])
    |> validate_required([:name, :description, :provider_ref])
    |> put_provider()
  end

  defp put_provider(changeset) do
    put_change(changeset, :provider, Atom.to_string(Config.tax_provider()))
  end
end
