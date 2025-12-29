defmodule Upload.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :email, :string
      add :provider, :string
      add :uid, :string
      add :name, :string
      add :avatar_url, :string
      add :role, :string, default: "user", null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:provider, :uid])
  end
end
