defmodule Harbor.Repo.Migrations.CreateProducts do
  use Ecto.Migration

  def change do
    ## Products

    create table(:products) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :status, :string, null: false, default: "draft"
      add :tax_code_id, references(:tax_codes), null: false

      timestamps()
    end

    create constraint(:products, :check_status,
             check: "status in ('draft', 'active', 'archived')"
           )

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

      add :sku, :string, null: false
      add :price, :integer, null: false
      add :quantity_available, :integer, default: 0, null: false
      add :enabled, :boolean, null: false, default: false
      add :track_inventory, :boolean, null: false, default: true

      add :tax_code_id, references(:tax_codes)

      timestamps()
    end

    create index(:variants, [:product_id])
    create index(:variants, [:product_id, :enabled])
    create unique_index(:variants, [:sku])

    create constraint(:variants, :price_gte_zero, check: "price >= 0")
    create constraint(:variants, :quantity_available_gte_zero, check: "quantity_available >= 0")

    create table(:variants_option_values, primary_key: false) do
      add :variant_id, references(:variants, on_delete: :delete_all), primary_key: true
      add :option_value_id, references(:option_values, on_delete: :delete_all), primary_key: true
    end

    create index(:variants_option_values, [:option_value_id])

    alter table(:products) do
      add :default_variant_id, :binary_id
    end

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
  end
end
