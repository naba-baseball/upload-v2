defmodule Upload.Repo.Migrations.AddSiteIdToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :site_id, references(:sites, on_delete: :nilify_all)
    end

    create index(:users, [:site_id])

    # Drop the user_sites join table since we don't need it anymore
    drop table(:user_sites)
  end
end
