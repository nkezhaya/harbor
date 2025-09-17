defmodule Harbor.Repo.Migrations.CreateCategories do
  use Ecto.Migration

  def change do
    create table(:categories) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :position, :integer, null: false, default: 0
      add :parent_id, references(:categories)
      add :parent_ids, {:array, :integer}, null: false, default: []

      timestamps()
    end

    create unique_index(:categories, [:slug])
    create unique_index(:categories, [:parent_id, :name])
    create unique_index(:categories, [:parent_id, :position], where: "parent_id IS NOT NULL")
    create unique_index(:categories, [:position], where: "parent_id IS NULL")
    create index(:categories, [:parent_ids], using: :gin)

    create constraint(:categories, :parent_cannot_be_self,
             check: "parent_id IS NULL OR parent_id != id"
           )

    create table(:products_categories, primary_key: false) do
      add :product_id, references(:products, on_delete: :delete_all), primary_key: true
      add :category_id, references(:categories, on_delete: :delete_all), primary_key: true
    end

    create index(:products_categories, [:product_id])
    create index(:products_categories, [:category_id])
  end
end
