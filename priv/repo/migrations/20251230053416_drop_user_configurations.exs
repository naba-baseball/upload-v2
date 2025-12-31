defmodule Upload.Repo.Migrations.DropUserConfigurations do
  use Ecto.Migration

  def change do
    drop table(:user_configurations)
  end
end
