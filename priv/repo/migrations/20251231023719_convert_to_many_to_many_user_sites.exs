defmodule Upload.Repo.Migrations.ConvertToManyToManyUserSites do
  use Ecto.Migration

  def change do
    # 1. Create join table
    create table(:user_sites) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :site_id, references(:sites, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:user_sites, [:user_id, :site_id])
    create index(:user_sites, [:site_id])

    # 2. Flush to ensure table exists before data migration
    flush()

    # 3. Migrate existing data from users.site_id to user_sites
    execute(
      """
      INSERT INTO user_sites (user_id, site_id, inserted_at, updated_at)
      SELECT id, site_id, NOW(), NOW() FROM users WHERE site_id IS NOT NULL
      """,
      """
      UPDATE users u
      SET site_id = us.site_id
      FROM user_sites us
      WHERE u.id = us.user_id
      """
    )

    # 4. Drop the site_id foreign key column from users
    alter table(:users) do
      remove :site_id, references(:sites, on_delete: :nilify_all)
    end
  end
end
