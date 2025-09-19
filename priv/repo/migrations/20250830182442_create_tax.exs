defmodule Harbor.Repo.Migrations.CreateTax do
  use Ecto.Migration

  def change do
    ## Tax Codes

    create table(:tax_codes) do
      add :name, :string, null: false
      add :description, :text, null: false
      add :provider, :string, null: false
      add :provider_ref, :string, null: false

      add :position, :integer, null: false, generated: "ALWAYS AS IDENTITY"

      add :effective_at, :timestamptz
      add :ended_at, :timestamptz

      timestamps()
    end

    create constraint(:tax_codes, :check_effective_window,
             check: "(effective_at IS NULL OR ended_at IS NULL OR effective_at <= ended_at)"
           )

    create unique_index(:tax_codes, [:provider, :provider_ref])
    create index(:tax_codes, [:position])
  end
end
