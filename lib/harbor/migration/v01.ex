defmodule Harbor.Migration.V01 do
  @moduledoc false

  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS pg_trgm"
    execute "CREATE EXTENSION IF NOT EXISTS tcn"
    execute "CREATE EXTENSION IF NOT EXISTS citext"

    execute(Money.DDL.create_money_with_currency())

    ## Tax Codes

    create table(:tax_codes, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
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

    create table(:categories, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :name, :string, null: false
      add :slug, :string, null: false
      add :position, :integer, null: false, default: 0
      add :parent_id, references(:categories, type: :binary_id)
      add :parent_ids, {:array, :binary_id}, null: false, default: []
      add :tax_code_id, references(:tax_codes, type: :binary_id), null: false

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
    """

    ## Products

    create table(:products, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "draft"
      add :physical_product, :boolean, null: false, default: true
      add :category_id, references(:categories, type: :binary_id), null: false
      add :tax_code_id, references(:tax_codes, type: :binary_id)
      add :default_variant_id, :binary_id

      timestamps()
    end

    create constraint(:products, :check_status,
             check: "status in ('draft', 'active', 'archived')"
           )

    create index(:products, [:category_id])
    create unique_index(:products, [:slug], where: "status = 'active'")

    execute "CREATE INDEX products_name_trgm ON products USING gin (name gin_trgm_ops)"

    ## Variants

    create table(:option_types, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :name, :string, null: false
      add :slug, :string, null: false

      add :product_id,
          references(:products, type: :binary_id, on_delete: :delete_all),
          null: false

      add :position, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(:option_types, [:product_id, :name])
    create unique_index(:option_types, [:product_id, :slug])
    create constraint(:option_types, :position_gte_zero, check: "position >= 0")

    create table(:option_values, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :name, :string, null: false
      add :slug, :string, null: false

      add :option_type_id,
          references(:option_types, type: :binary_id, on_delete: :delete_all),
          null: false

      add :position, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(:option_values, [:option_type_id, :name])
    create unique_index(:option_values, [:option_type_id, :slug])
    create constraint(:option_values, :position_gte_zero, check: "position >= 0")

    create table(:variants, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")

      add :product_id,
          references(:products, type: :binary_id, on_delete: :delete_all),
          null: false

      add :sku, :string
      add :price, :money_with_currency, null: false
      add :quantity_available, :integer, default: 0, null: false
      add :enabled, :boolean, null: false, default: false
      add :inventory_policy, :string, null: false, default: "not_tracked"
      add :tax_code_id, references(:tax_codes, type: :binary_id)

      timestamps()
    end

    create index(:variants, [:product_id])
    create index(:variants, [:product_id, :enabled])
    create unique_index(:variants, [:sku], where: "sku IS NOT NULL")

    create constraint(:variants, :price_gte_zero, check: "(price).amount >= 0")
    create constraint(:variants, :quantity_available_gte_zero, check: "quantity_available >= 0")

    create constraint(:variants, :inventory_policy_allowed,
             check: "inventory_policy IN ('not_tracked', 'track_strict', 'track_allow')"
           )

    create table(:variants_option_values, primary_key: false) do
      add :variant_id,
          references(:variants, type: :binary_id, on_delete: :delete_all),
          primary_key: true

      add :option_value_id,
          references(:option_values, type: :binary_id, on_delete: :delete_all),
          primary_key: true
    end

    create index(:variants_option_values, [:option_value_id])

    # This seems redundant, but is required so we can create a composite foreign
    # key on the products table based on (variants.id, variants.product_id)
    execute "ALTER TABLE variants ADD CONSTRAINT variants_primary UNIQUE (id, product_id)"

    # Ensure that the variant pointed to by "products" is actually a variant of
    # the specific product
    execute """
    ALTER TABLE products ADD CONSTRAINT products_default_variant_id_fkey
      FOREIGN KEY (default_variant_id, id) REFERENCES variants(id, product_id)
      ON DELETE SET NULL DEFERRABLE INITIALLY IMMEDIATE
    """

    create index(:products, [:default_variant_id])

    create table(:product_images, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :status, :string, null: false, default: "draft"
      add :file_name, :string, null: false
      add :file_size, :integer, null: false
      add :file_type, :string, null: false
      add :alt_text, :string
      add :image_path, :string, null: false
      add :temp_upload_path, :string

      add :product_id,
          references(:products, type: :binary_id, on_delete: :delete_all),
          null: false

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
    """

    ## Users

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :email, :citext, null: false
      add :hashed_password, :string
      add :confirmed_at, :timestamptz

      timestamps()
    end

    create unique_index(:users, [:email])

    ## Tokens

    create table(:users_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
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
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all),
        primary_key: true

      add :role, :string, primary_key: true

      timestamps(updated_at: false)
    end

    create constraint(:users_roles, :check_role, check: "role in ('superadmin', 'admin')")

    ## Customers

    create table(:customers, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
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

    create table(:addresses, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")

      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all),
        null: false

      add :first_name, :string
      add :last_name, :string
      add :line1, :string
      add :line2, :string
      add :city, :string
      add :region, :string
      add :postal_code, :string
      add :country, :string, null: false
      add :phone, :string, null: false

      timestamps()
    end

    create index(:addresses, [:customer_id])

    alter table(:customers) do
      modify :default_shipping_address_id,
             references(:addresses, type: :binary_id, on_delete: :nilify_all)

      modify :default_billing_address_id,
             references(:addresses, type: :binary_id, on_delete: :nilify_all)
    end

    ## Delivery methods

    create table(:delivery_methods, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :name, :string, null: false
      add :price, :money_with_currency, null: false
      add :fulfillment_type, :string, null: false

      timestamps()
    end

    create unique_index(:delivery_methods, [:name])
    create constraint(:delivery_methods, :price_gte_zero, check: "(price).amount >= 0")

    create constraint(:delivery_methods, :check_fulfillment_type,
             check: "fulfillment_type in ('ship', 'pickup')"
           )

    ## Orders

    create table(:orders, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :status, :string, null: false, default: "draft"
      add :number, :string, null: false
      add :customer_id, references(:customers, type: :binary_id)
      add :email, :string

      add :billing_address_id, references(:addresses, type: :binary_id, on_delete: :nilify_all)
      add :shipping_address_id, references(:addresses, type: :binary_id, on_delete: :nilify_all)

      add :delivery_method_id,
          references(:delivery_methods, type: :binary_id, on_delete: :nilify_all)

      add :address_name, :string
      add :address_line1, :string
      add :address_line2, :string
      add :address_city, :string
      add :address_region, :string
      add :address_postal_code, :string
      add :address_country, :string
      add :address_phone, :string

      add :delivery_method_name, :string

      add :subtotal, :money_with_currency, null: false
      add :tax, :money_with_currency, null: false
      add :shipping_price, :money_with_currency, null: false

      add :total_price, :money_with_currency,
        generated:
          "ALWAYS AS (ROW('USD', (subtotal).amount + (tax).amount + (shipping_price).amount)::money_with_currency) STORED",
        null: false

      add :notes, :text

      timestamps()
    end

    create index(:orders, [:customer_id])
    create unique_index(:orders, [:number])

    create constraint(:orders, :check_status,
             check: "status in ('draft', 'pending', 'paid', 'shipped', 'delivered', 'canceled')"
           )

    create constraint(:orders, :subtotal_gte_zero, check: "(subtotal).amount >= 0")
    create constraint(:orders, :tax_gte_zero, check: "(tax).amount >= 0")
    create constraint(:orders, :shipping_price_gte_zero, check: "(shipping_price).amount >= 0")

    ## Order Items

    create table(:order_items, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :order_id, references(:orders, type: :binary_id, on_delete: :delete_all), null: false
      add :variant_id, references(:variants, type: :binary_id), null: false
      add :quantity, :integer, null: false
      add :price, :money_with_currency, null: false

      timestamps()
    end

    create index(:order_items, [:order_id])
    create index(:order_items, [:variant_id])
    create unique_index(:order_items, [:order_id, :variant_id])
    create constraint(:order_items, :quantity_gte_zero, check: "quantity > 0")
    create constraint(:order_items, :price_gte_zero, check: "(price).amount >= 0")

    ## Carts

    create table(:carts, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all)
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

    alter table(:orders) do
      add :cart_id, references(:carts, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:orders, [:cart_id])

    ## Cart items

    create table(:cart_items, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :cart_id, references(:carts, type: :binary_id, on_delete: :delete_all), null: false

      add :variant_id, references(:variants, type: :binary_id, on_delete: :delete_all),
        null: false

      add :quantity, :integer, null: false

      timestamps()
    end

    create index(:cart_items, [:variant_id])
    create unique_index(:cart_items, [:cart_id, :variant_id])
    create constraint(:cart_items, :quantity_gte_zero, check: "quantity > 0")

    ## Payment Profiles

    create table(:payment_profiles, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :provider, :string, null: false
      add :provider_ref, :string, null: false

      add :customer_id, references(:customers, type: :binary_id, on_delete: :delete_all),
        null: false

      timestamps()
    end

    create unique_index(:payment_profiles, [:provider, :provider_ref])
    create unique_index(:payment_profiles, [:provider, :customer_id])

    ## Payment Methods

    create table(:payment_methods, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")

      add :payment_profile_id,
          references(:payment_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :provider_ref, :string, null: false
      add :type, :string, null: false
      add :default, :boolean, null: false, default: false
      add :details, :map, null: false, default: %{}
      add :deleted_at, :timestamptz

      timestamps()
    end

    create unique_index(:payment_methods, [:provider_ref])

    create unique_index(:payment_methods, [:payment_profile_id, :default],
             where: "\"default\" = true"
           )

    ## Payment Intents

    create table(:payment_intents, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")

      add :payment_profile_id,
          references(:payment_profiles, type: :binary_id, on_delete: :delete_all),
          null: false

      add :provider, :string, null: false
      add :provider_ref, :string, null: false
      add :status, :string, null: false
      add :amount, :integer, null: false
      add :currency, :string, null: false
      add :client_secret, :string, null: false
      add :metadata, :map, null: false, default: %{}

      timestamps()
    end

    create unique_index(:payment_intents, [:provider, :provider_ref])
    create index(:payment_intents, [:payment_profile_id])

    ## Checkout sessions

    create table(:checkout_sessions, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :order_id, references(:orders, type: :binary_id, on_delete: :delete_all), null: false
      add :status, :string, null: false, default: "active"
      add :current_step, :string
      add :last_touched_at, :timestamptz
      add :expires_at, :timestamptz, null: false

      # payments
      add :payment_intent_id,
          references(:payment_intents, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:checkout_sessions, [:order_id])
    create index(:checkout_sessions, [:expires_at])

    create constraint(:checkout_sessions, :check_status,
             check: "status in ('active', 'abandoned', 'completed', 'expired')"
           )

    create constraint(:checkout_sessions, :check_current_step,
             check:
               "current_step IS NULL OR current_step in ('contact', 'shipping', 'delivery', 'payment', 'review')"
           )

    ## Tax Calculations

    create table(:tax_calculations, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :provider_ref, :string, null: false
      add :order_id, references(:orders, type: :binary_id, on_delete: :delete_all), null: false
      add :amount, :integer, null: false
      add :hash, :string, null: false

      timestamps()
    end

    create unique_index(:tax_calculations, [:provider_ref])
    create unique_index(:tax_calculations, [:order_id, :hash])

    ## Tax Calculation Line Items

    create table(:tax_calculation_line_items, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :provider_ref, :string, null: false

      add :order_item_id,
          references(:order_items, type: :binary_id, on_delete: :delete_all),
          null: false

      add :calculation_id,
          references(:tax_calculations, type: :binary_id, on_delete: :delete_all),
          null: false

      add :amount, :integer, null: false
    end

    create unique_index(:tax_calculation_line_items, [:provider_ref])

    ## Tax transactions

    create table(:tax_transaction_line_items, primary_key: false) do
      add :id, :binary_id, primary_key: true, default: fragment("uuidv7()")
      add :provider_ref, :string, null: false

      add :order_item_id,
          references(:order_items, type: :binary_id, on_delete: :delete_all),
          null: false
    end

    create unique_index(:tax_transaction_line_items, [:order_item_id])
    create unique_index(:tax_transaction_line_items, [:provider_ref])

    ## Settings

    create table(:settings, primary_key: false) do
      add :id, :boolean, primary_key: true, default: true
      add :payments_enabled, :boolean, null: false, default: true
      add :delivery_enabled, :boolean, null: false, default: true
      add :tax_enabled, :boolean, null: false, default: true
    end

    create constraint(:settings, :singleton, check: "id")

    execute "INSERT INTO settings (id) VALUES (true)"

    execute """
    CREATE TRIGGER harbor_settings_changed
    AFTER INSERT OR UPDATE ON settings
    FOR EACH ROW
    EXECUTE FUNCTION triggered_change_notification('harbor_settings_changed')
    """
  end

  def down do
    drop_if_exists table(:tax_transaction_line_items)
    drop_if_exists table(:tax_calculation_line_items)
    drop_if_exists table(:tax_calculations)
    drop_if_exists table(:checkout_sessions)
    drop_if_exists table(:payment_intents)
    drop_if_exists table(:payment_methods)
    drop_if_exists table(:payment_profiles)
    drop_if_exists table(:cart_items)

    # Remove cart_id from orders before dropping carts
    alter table(:orders) do
      remove :cart_id
    end

    drop_if_exists table(:carts)
    drop_if_exists table(:order_items)
    drop_if_exists table(:orders)
    drop_if_exists table(:delivery_methods)

    # Remove address FKs from customers before dropping addresses
    execute "ALTER TABLE customers DROP CONSTRAINT IF EXISTS customers_default_shipping_address_id_fkey"

    execute "ALTER TABLE customers DROP CONSTRAINT IF EXISTS customers_default_billing_address_id_fkey"

    drop_if_exists table(:addresses)
    drop_if_exists table(:customers)
    drop_if_exists table(:users_roles)
    drop_if_exists table(:users_tokens)
    drop_if_exists table(:users)

    # Remove default_variant_id FK from products before dropping variants
    execute "ALTER TABLE products DROP CONSTRAINT IF EXISTS products_default_variant_id_fkey"

    drop_if_exists table(:product_images)
    drop_if_exists table(:variants_option_values)
    drop_if_exists table(:variants)
    drop_if_exists table(:option_values)
    drop_if_exists table(:option_types)
    drop_if_exists table(:products)
    drop_if_exists table(:categories)
    drop_if_exists table(:tax_codes)

    execute "DROP TRIGGER IF EXISTS harbor_settings_changed ON settings"
    drop_if_exists table(:settings)

    execute(Money.DDL.drop_money_with_currency())
  end
end
