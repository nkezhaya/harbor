defmodule Harbor.Repo.Migrations.CreateOrders do
  use Ecto.Migration

  def change do
    ## Orders

    create table(:orders) do
      add :status, :string, null: false, default: "pending"
      add :number, :string, null: false
      add :user_id, references(:users)
      add :email, :string, null: false

      add :address_name, :string
      add :address_line1, :string
      add :address_line2, :string
      add :address_city, :string
      add :address_region, :string
      add :address_postal_code, :string
      add :address_country, :string
      add :address_phone, :string

      add :delivery_method_name, :string, null: false

      add :subtotal, :integer, null: false
      add :tax, :integer, null: false
      add :shipping_price, :integer, null: false

      add :total_price, :integer,
        generated: "ALWAYS AS (subtotal + tax + shipping_price) STORED",
        null: false

      timestamps()
    end

    create index(:orders, [:user_id])
    create unique_index(:orders, [:number])

    create constraint(:orders, :check_status,
             check: "status in ('pending', 'paid', 'shipped', 'delivered', 'canceled')"
           )

    create constraint(:orders, :subtotal_gte_zero, check: "subtotal >= 0")
    create constraint(:orders, :tax_gte_zero, check: "tax >= 0")
    create constraint(:orders, :shipping_price_gte_zero, check: "shipping_price >= 0")

    ## Order Items

    create table(:order_items) do
      add :order_id, references(:orders, on_delete: :delete_all), null: false
      add :variant_id, references(:variants), null: false
      add :quantity, :integer, null: false
      add :price, :integer, null: false

      timestamps()
    end

    create index(:order_items, [:order_id])
    create index(:order_items, [:variant_id])
    create unique_index(:order_items, [:order_id, :variant_id])
    create constraint(:order_items, :quantity_gte_zero, check: "quantity > 0")
    create constraint(:order_items, :price_gte_zero, check: "price >= 0")
  end
end
