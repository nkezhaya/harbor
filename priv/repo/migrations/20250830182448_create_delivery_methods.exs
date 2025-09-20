defmodule Harbor.Repo.Migrations.CreateDeliveryMethods do
  use Ecto.Migration

  def change do
    create table(:delivery_methods) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, null: false
      add :price, :integer, null: false
      add :fulfillment_type, :string, null: false

      timestamps()
    end

    create unique_index(:delivery_methods, [:name])
    create constraint(:delivery_methods, :price_gte_zero, check: "price >= 0")

    create constraint(:delivery_methods, :check_fulfillment_type,
             check: "fulfillment_type in ('ship', 'pickup')"
           )
  end
end
