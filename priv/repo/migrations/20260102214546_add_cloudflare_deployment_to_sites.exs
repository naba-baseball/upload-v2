defmodule Upload.Repo.Migrations.AddCloudflareDeploymentToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :cloudflare_worker_name, :string
      add :deployment_status, :string, default: "pending"
      add :last_deployed_at, :utc_datetime
      add :last_deployment_error, :text
    end
  end
end
