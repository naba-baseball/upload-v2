defmodule Upload.Repo.Migrations.CreateSiteWebhooks do
  use Ecto.Migration

  def change do
    create table(:site_webhooks) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :url, :string, null: false
      add :description, :string
      add :events, {:array, :string}, default: [], null: false
      add :role_mention, :string
      add :payload_template, :map, default: %{}
      add :is_active, :boolean, default: true, null: false
      add :last_response_status, :integer
      add :last_response_body, :text
      add :last_triggered_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:site_webhooks, [:site_id])
    create index(:site_webhooks, [:is_active])
  end
end
