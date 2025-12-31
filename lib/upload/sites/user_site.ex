defmodule Upload.Sites.UserSite do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_sites" do
    belongs_to :user, Upload.Accounts.User
    belongs_to :site, Upload.Sites.Site

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user_site, attrs) do
    user_site
    |> cast(attrs, [])
    |> unique_constraint([:user_id, :site_id])
  end
end
