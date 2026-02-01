defmodule Upload.Repo.Migrations.AddFormatVersionToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :format_version, :string, null: false, default: "ootp23"
    end

    create index(:sites, [:format_version])
  end
end
