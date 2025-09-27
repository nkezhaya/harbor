defmodule Harbor.Repo.Migrations.CreateProductImages do
  use Ecto.Migration

  def change do
    create table(:product_images) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :status, :string, null: false, default: "pending"
      add :image_path, :string, null: false
      add :temp_upload_path, :string
      add :product_id, references(:products, on_delete: :nilify_all), null: false
      add :position, :integer, null: false, default: 0

      timestamps()
    end

    create constraint(:product_images, :check_status, check: "status in ('pending', 'ready')")

    create constraint(:product_images, :check_temp_upload_path,
             check: "temp_upload_path IS NOT NULL OR status = 'ready'"
           )

    create index(:product_images, [:product_id])
    create unique_index(:product_images, [:product_id, :position])

    create constraint(:product_images, :position_gte_zero, check: "position >= 0")
  end
end
