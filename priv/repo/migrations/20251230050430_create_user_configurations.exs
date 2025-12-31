defmodule Upload.Repo.Migrations.CreateUserConfigurations do
  use Ecto.Migration

  def change do
    create table(:user_configurations) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :subdomain, :string
      add :base_domain, :string, default: "nabaleague.com"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_configurations, [:user_id])
    create unique_index(:user_configurations, [:subdomain], where: "subdomain IS NOT NULL")
  end
end
