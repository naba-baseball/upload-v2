defmodule Upload.Repo.Migrations.CreateUserConfigurations do
  use Ecto.Migration

  @default_base_domain Application.compile_env(:upload, :base_domain)

  def change do
    create table(:user_configurations) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :subdomain, :string
      add :base_domain, :string, default: @default_base_domain

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_configurations, [:user_id])
    create unique_index(:user_configurations, [:subdomain], where: "subdomain IS NOT NULL")
  end
end
