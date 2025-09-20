defmodule Harbor.Repo.Migrations.CreateCarts do
  use Ecto.Migration

  def change do
    ## Carts

    create table(:carts) do
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
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
      add :id, :binary_id, primary_key: true, default: fragment("gen_random_uuid()")
      add :cart_id, references(:carts, on_delete: :delete_all), null: false
      add :variant_id, references(:variants, on_delete: :delete_all), null: false
      add :quantity, :integer, null: false

      timestamps()
    end

    create index(:cart_items, [:variant_id])
    create unique_index(:cart_items, [:cart_id, :variant_id])
    create constraint(:cart_items, :quantity_gte_zero, check: "quantity > 0")
  end
end
