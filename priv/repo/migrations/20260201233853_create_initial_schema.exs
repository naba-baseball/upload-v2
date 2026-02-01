defmodule Upload.Repo.Migrations.CreateInitialSchema do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string, null: false
      add :provider, :string, null: false
      add :uid, :string, null: false
      add :name, :string
      add :avatar_url, :string
      add :role, :string, null: false, default: "user"
      add :inserted_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
    end

    create unique_index(:users, [:provider, :uid])

    create table(:sites) do
      add :name, :string, null: false
      add :subdomain, :string, null: false
      add :routing_mode, :string, null: false, default: "subdomain"
      add :format_version, :string, null: false, default: "ootp23"
      add :deployment_status, :string, null: false, default: "pending"
      add :last_deployed_at, :utc_datetime
      add :last_deployment_error, :text
      add :inserted_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
    end

    create unique_index(:sites, [:subdomain])
    create index(:sites, [:format_version])

    create table(:user_sites) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :inserted_at, :utc_datetime, null: false
      add :updated_at, :utc_datetime, null: false
    end

    create unique_index(:user_sites, [:user_id, :site_id])
    create index(:user_sites, [:user_id])
    create index(:user_sites, [:site_id])
  end
end
