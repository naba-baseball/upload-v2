defmodule Upload.Repo.Migrations.CreateUserSites do
  use Ecto.Migration

  def change do
    create table(:user_sites) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :site_id, references(:sites, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_sites, [:user_id, :site_id])
    create index(:user_sites, [:user_id])
    create index(:user_sites, [:site_id])
  end
end
