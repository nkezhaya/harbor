defmodule Harbor.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    ## Products

    create table(:products) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "draft"

      timestamps()
    end

    create constraint(:products, :check_status,
             check: "status in ('draft', 'active', 'archived')"
           )

    create unique_index(:products, [:slug])

    ## Variants

    create table(:option_types) do
      add :name, :string, null: false
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :position, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(:option_types, [:product_id, :name])
    create constraint(:option_types, :position_gte_zero, check: "position >= 0")

    create table(:option_values) do
      add :name, :string, null: false
      add :option_type_id, references(:option_types, on_delete: :delete_all), null: false
      add :position, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(:option_values, [:option_type_id, :name])
    create constraint(:option_values, :position_gte_zero, check: "position >= 0")

    create table(:variants) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :master, :boolean, null: false, default: false

      add :sku, :string, null: false
      add :price, :integer, null: false
      add :quantity_available, :integer, default: 0, null: false
      add :enabled, :boolean, null: false, default: false
      add :track_inventory, :boolean, null: false, default: true

      timestamps()
    end

    create index(:variants, [:product_id])
    create index(:variants, [:product_id, :enabled])
    create unique_index(:variants, [:sku])

    create unique_index(:variants, [:product_id],
             name: "variants_product_id_master_index",
             where: "master = true"
           )

    create constraint(:variants, :price_gte_zero, check: "price >= 0")
    create constraint(:variants, :quantity_available_gte_zero, check: "quantity_available >= 0")

    create table(:variants_option_values, primary_key: false) do
      add :variant_id, references(:variants, on_delete: :delete_all),
        null: false,
        primary_key: true

      add :option_value_id, references(:option_values, on_delete: :delete_all),
        null: false,
        primary_key: true
    end

    create index(:variants_option_values, [:option_value_id])
  end
end
