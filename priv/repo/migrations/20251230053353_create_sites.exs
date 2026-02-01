defmodule Upload.Repo.Migrations.CreateSites do
  use Ecto.Migration

  @default_base_domain Application.compile_env(:upload, :base_domain)

  def change do
    create table(:sites) do
      add :name, :string, null: false
      add :subdomain, :string, null: false
      add :base_domain, :string, default: @default_base_domain, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:sites, [:subdomain])
  end
end
