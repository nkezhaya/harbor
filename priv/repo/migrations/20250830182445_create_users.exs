defmodule Harbor.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users) do
      add :email, :citext, null: false
      add :hashed_password, :string
      add :confirmed_at, :timestamptz

      timestamps()
    end

    create unique_index(:users, [:email])

    ## Tokens

    create table(:users_tokens) do
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
  end
end
