defmodule Upload.Repo.Migrations.AddRoutingModeToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :routing_mode, :string, default: "subdomain", null: false
    end
  end
end
