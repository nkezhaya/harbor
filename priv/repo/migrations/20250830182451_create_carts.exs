defmodule Harbor.Repo.Migrations.CreateCarts do
  use Ecto.Migration

  def change do
    ## Carts

    create table(:carts) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :session_token, :string

      timestamps()
    end

    create unique_index(:carts, [:user_id], where: "user_id IS NOT NULL")
    create unique_index(:carts, [:session_token], where: "session_token IS NOT NULL")

    create constraint(:carts, :user_or_session_token,
             check: "user_id IS NOT NULL OR session_token IS NOT NULL"
           )

    ## Cart items

    create table(:cart_items) do
      add :cart_id, references(:carts, on_delete: :delete_all), null: false
      add :variant_id, references(:variants, on_delete: :delete_all), null: false
      add :quantity, :integer, null: false

      timestamps()
    end

    create index(:cart_items, [:variant_id])
    create unique_index(:cart_items, [:cart_id, :variant_id])
    create constraint(:cart_items, :quantity_gte_zero, check: "quantity > 0")

    ## Checkout sessions

    create table(:checkout_sessions) do
      add :cart_id, references(:carts, on_delete: :delete_all), null: false
      add :order_id, references(:orders, on_delete: :delete_all), null: true
      add :status, :string, null: false, default: "active"
      add :expires_at, :timestamptz, null: false

      add :billing_address_id, references(:addresses, on_delete: :nilify_all)
      add :shipping_address_id, references(:addresses, on_delete: :nilify_all)
      add :delivery_method_id, references(:delivery_methods, on_delete: :nilify_all)

      # payments (provider refs only)
      add :payment_intent_id, :string
      add :payment_method_ref, :string

      # guest email if not logged in
      add :email, :string

      timestamps()
    end

    create unique_index(:checkout_sessions, [:cart_id], where: "status = 'active'")
    create unique_index(:checkout_sessions, [:order_id], where: "order_id IS NOT NULL")
    create index(:checkout_sessions, [:expires_at])

    create constraint(:checkout_sessions, :check_status,
             check: "status in ('active', 'abandoned', 'completed', 'expired')"
           )
  end
end
