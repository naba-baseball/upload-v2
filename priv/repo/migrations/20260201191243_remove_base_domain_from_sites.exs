defmodule Upload.Repo.Migrations.RemoveBaseDomainFromSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      remove :base_domain
    end
  end
end
