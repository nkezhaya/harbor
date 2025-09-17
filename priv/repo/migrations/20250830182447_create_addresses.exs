defmodule Harbor.Repo.Migrations.CreateAddresses do
  use Ecto.Migration

  def change do
    create table(:addresses) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :default, :boolean, null: false, default: false

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

    create index(:addresses, [:user_id])

    create unique_index(:addresses, [:user_id],
             name: "addresses_user_id_default_index",
             where: "\"default\" = true"
           )
  end
end
