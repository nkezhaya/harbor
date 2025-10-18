defmodule Harbor.Repo.Migrations.InstallV1 do
  use Ecto.Migration

  def change do
    ## Tax Codes

    create table(:tax_codes) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
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

    ## Categories

    create table(:categories) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, null: false
      add :slug, :string, null: false
      add :position, :integer, null: false, default: 0
      add :parent_id, references(:categories)
      add :parent_ids, {:array, :integer}, null: false, default: []
      add :tax_code_id, references(:tax_codes), null: false

      timestamps()
    end

    create unique_index(:categories, [:slug])
    create unique_index(:categories, [:parent_id, :name], nulls_distinct: false)
    create index(:categories, [:parent_id, :position])
    create index(:categories, [:parent_ids], using: :gin)

    create constraint(:categories, :parent_cannot_be_self,
             check: "parent_id IS NULL OR parent_id != id"
           )

    execute """
            ALTER TABLE categories
                ADD CONSTRAINT categories_parent_id_position_unique
                UNIQUE NULLS NOT DISTINCT (parent_id, position)
                DEFERRABLE INITIALLY DEFERRED
            """,
            ""

    ## Products

    create table(:products) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "draft"
      add :category_id, references(:categories), null: false
      add :tax_code_id, references(:tax_codes)
      add :default_variant_id, :binary_id

      timestamps()
    end

    create constraint(:products, :check_status,
             check: "status in ('draft', 'active', 'archived')"
           )

    create index(:products, [:category_id])
    create unique_index(:products, [:slug], where: "status = 'active'")

    ## Variants

    create table(:option_types) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, null: false
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :position, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(:option_types, [:product_id, :name])
    create constraint(:option_types, :position_gte_zero, check: "position >= 0")

    create table(:option_values) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, null: false
      add :option_type_id, references(:option_types, on_delete: :delete_all), null: false
      add :position, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(:option_values, [:option_type_id, :name])
    create constraint(:option_values, :position_gte_zero, check: "position >= 0")

    create table(:variants) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :product_id, references(:products, on_delete: :delete_all), null: false

      add :sku, :string
      add :price, :integer, null: false
      add :quantity_available, :integer, default: 0, null: false
      add :enabled, :boolean, null: false, default: false
      add :inventory_policy, :string, null: false, default: "not_tracked"

      add :tax_code_id, references(:tax_codes)

      timestamps()
    end

    create index(:variants, [:product_id])
    create index(:variants, [:product_id, :enabled])
    create unique_index(:variants, [:sku], where: "sku IS NOT NULL")

    create constraint(:variants, :price_gte_zero, check: "price >= 0")
    create constraint(:variants, :quantity_available_gte_zero, check: "quantity_available >= 0")

    create constraint(:variants, :inventory_policy_allowed,
             check: "inventory_policy IN ('not_tracked', 'track_strict', 'track_allow')"
           )

    create table(:variants_option_values, primary_key: false) do
      add :variant_id, references(:variants, on_delete: :delete_all), primary_key: true
      add :option_value_id, references(:option_values, on_delete: :delete_all), primary_key: true
    end

    create index(:variants_option_values, [:option_value_id])

    # This seems redundant, but is required so we can create a composite foreign
    # key on the products table based on (variants.id, variants.product_id)
    execute(
      "ALTER TABLE variants ADD CONSTRAINT variants_primary UNIQUE (id, product_id)",
      "ALTER TABLE variants DROP CONSTRAINT variants_primary"
    )

    # Ensure that the variant pointed to by "products" is actually a variant of
    # the specific product
    execute(
      """
      ALTER TABLE products ADD CONSTRAINT products_default_variant_id_fkey
        FOREIGN KEY (default_variant_id, id) REFERENCES variants(id, product_id)
        ON DELETE SET NULL DEFERRABLE INITIALLY IMMEDIATE
      """,
      "ALTER TABLE products DROP CONSTRAINT products_default_variant_id_fkey"
    )

    create index(:products, [:default_variant_id])

    create table(:product_images) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :status, :string, null: false, default: "pending"
      add :file_name, :string, null: false
      add :file_size, :integer, null: false
      add :file_type, :string, null: false
      add :alt_text, :string
      add :image_path, :string, null: false
      add :temp_upload_path, :string
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :position, :integer, null: false, default: 0

      timestamps()
    end

    create constraint(:product_images, :check_status, check: "status IN ('pending', 'ready')")

    create constraint(:product_images, :check_temp_upload_path,
             check: "temp_upload_path IS NOT NULL OR status = 'ready'"
           )

    create index(:product_images, [:product_id])
    create index(:product_images, [:product_id, :position])

    create constraint(:product_images, :position_gte_zero, check: "position >= 0")

    execute """
            ALTER TABLE product_images
                ADD CONSTRAINT product_images_product_id_position_unique UNIQUE (product_id, position) DEFERRABLE INITIALLY DEFERRED
            """,
            ""

    ## Users

    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :email, :citext, null: false
      add :hashed_password, :string
      add :confirmed_at, :timestamptz

      timestamps()
    end

    create unique_index(:users, [:email])

    ## Tokens

    create table(:users_tokens) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :timestamptz

      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])

    ## Roles

    create table(:users_roles, primary_key: false) do
      add :user_id, references(:users, on_delete: :delete_all), primary_key: true
      add :role, :string, primary_key: true

      timestamps(updated_at: false)
    end

    create constraint(:users_roles, :check_role, check: "role in ('superadmin', 'admin')")

    ## Customers

    create table(:customers) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :first_name, :string
      add :last_name, :string
      add :company_name, :string
      add :email, :citext, null: false
      add :phone, :citext
      add :status, :string, default: "active"
      add :default_shipping_address_id, :binary_id
      add :default_billing_address_id, :binary_id
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :deleted_at, :timestamptz

      timestamps()
    end

    create constraint(:customers, :check_status, check: "status in ('active', 'blocked')")
    create unique_index(:customers, [:user_id], where: "user_id IS NOT NULL")

    ## Addresses

    create table(:addresses) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :customer_id, references(:customers, on_delete: :delete_all), null: false

      add :name, :string, null: false
      add :line1, :string, null: false
      add :line2, :string
      add :city, :string, null: false
      add :region, :string
      add :postal_code, :string
      add :country, :string, null: false
      add :phone, :string, null: false

      timestamps()
    end

    create index(:addresses, [:customer_id])

    alter table(:customers) do
      modify :default_shipping_address_id, references(:addresses, on_delete: :nilify_all)
      modify :default_billing_address_id, references(:addresses, on_delete: :nilify_all)
    end

    ## Delivery methods

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

    ## Orders

    create table(:orders) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :status, :string, null: false, default: "pending"
      add :number, :string, null: false
      add :customer_id, references(:customers)
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

    create index(:orders, [:customer_id])
    create unique_index(:orders, [:number])

    create constraint(:orders, :check_status,
             check: "status in ('pending', 'paid', 'shipped', 'delivered', 'canceled')"
           )

    create constraint(:orders, :subtotal_gte_zero, check: "subtotal >= 0")
    create constraint(:orders, :tax_gte_zero, check: "tax >= 0")
    create constraint(:orders, :shipping_price_gte_zero, check: "shipping_price >= 0")

    ## Order Items

    create table(:order_items) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
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

    ## Carts

    create table(:carts) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :customer_id, references(:customers, on_delete: :delete_all)
      add :session_token, :string
      add :status, :string, null: false, default: "active"
      add :lock_version, :integer, null: false, default: 1
      add :last_touched_at, :timestamptz
      add :expires_at, :timestamptz, null: false

      timestamps()
    end

    create unique_index(:carts, [:customer_id],
             where: "customer_id IS NOT NULL AND status = 'active'"
           )

    create unique_index(:carts, [:session_token],
             where: "session_token IS NOT NULL AND status = 'active'"
           )

    create constraint(:carts, :customer_or_session_token,
             check: "customer_id IS NOT NULL OR session_token IS NOT NULL"
           )

    create constraint(:carts, :carts_check_status,
             check: "status in ('active', 'merged', 'expired')"
           )

    ## Cart items

    create table(:cart_items) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
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
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
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
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
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
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :provider_ref, :string, null: false
      add :cart_item_id, references(:cart_items, on_delete: :delete_all), null: false
      add :calculation_id, references(:tax_calculations, on_delete: :delete_all), null: false
      add :amount, :integer, null: false
    end

    create unique_index(:tax_calculation_line_items, [:provider_ref])

    # Tax transactions

    create table(:tax_transaction_line_items) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :provider_ref, :string, null: false
      add :order_item_id, references(:order_items, on_delete: :delete_all), null: false
    end

    create unique_index(:tax_transaction_line_items, [:order_item_id])
    create unique_index(:tax_transaction_line_items, [:provider_ref])

    ## Oban

    Oban.Migrations.up()
  end
end
