defmodule Harbor.Repo.Migrations.CreateProductImages do
  use Ecto.Migration

  def change do
    create table(:product_images) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :image, :string, null: false
      add :product_id, references(:products, on_delete: :nilify_all)
      add :position, :integer, null: false, default: 0

      timestamps()
    end

    create index(:product_images, [:product_id])

    create unique_index(:product_images, [:product_id, :position],
             where: "product_id IS NOT NULL"
           )

    create constraint(:product_images, :position_gte_zero, check: "position >= 0")
  end
end
