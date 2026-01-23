defmodule Upload.Repo.Migrations.RemoveCloudflareFieldsFromSites do
  use Ecto.Migration

  def up do
    # Reset all deployed sites to pending and set migration message
    execute """
    UPDATE sites
    SET deployment_status = 'pending',
        last_deployment_error = 'Migration required: Please re-upload your site files to complete the upgrade.'
    WHERE deployment_status = 'deployed'
    """

    # Remove cloudflare_worker_name column
    alter table(:sites) do
      remove :cloudflare_worker_name
    end
  end

  def down do
    # Re-add cloudflare_worker_name column
    alter table(:sites) do
      add :cloudflare_worker_name, :string
    end

    # Note: We cannot restore the previous deployment status or worker names
    # as that data was lost during the migration
  end
end
