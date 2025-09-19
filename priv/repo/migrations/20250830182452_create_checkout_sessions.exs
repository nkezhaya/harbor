defmodule Harbor.Repo.Migrations.CreateCheckoutSessions do
  use Ecto.Migration

  def change do
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

    ## Tax Calculations

    create table(:tax_calculations) do
      add :provider_ref, :string, null: false

      add :checkout_session_id, references(:checkout_sessions, on_delete: :delete_all),
        null: false

      add :amount, :integer, null: false
      add :hash, :integer, null: false

      timestamps()
    end

    create unique_index(:tax_calculations, [:provider_ref])
    create unique_index(:tax_calculations, [:checkout_session_id, :hash])

    ## Tax Calculation Line Items

    create table(:tax_calculation_line_items) do
      add :provider_ref, :string, null: false
      add :cart_item_id, references(:cart_items, on_delete: :delete_all), null: false
      add :calculation_id, references(:tax_calculations, on_delete: :delete_all), null: false
      add :amount, :integer, null: false
    end

    create unique_index(:tax_calculation_line_items, [:provider_ref])

    # Tax transactions

    create table(:tax_transaction_line_items) do
      add :provider_ref, :string, null: false
      add :order_item_id, references(:order_items, on_delete: :delete_all), null: false
    end

    create unique_index(:tax_transaction_line_items, [:order_item_id])
    create unique_index(:tax_transaction_line_items, [:provider_ref])
  end
end
