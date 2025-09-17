defmodule Harbor.Repo.Migrations.CreateDeliveryMethods do
  use Ecto.Migration

  def change do
    create table(:delivery_methods) do
      add :name, :string, null: false
      add :price, :integer, null: false

      timestamps()
    end

    create unique_index(:delivery_methods, [:name])
    create constraint(:delivery_methods, :price_gte_zero, check: "price >= 0")
  end
end
