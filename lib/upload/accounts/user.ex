defmodule Upload.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :provider, :string
    field :uid, :string
    field :name, :string
    field :avatar_url, :string
    field :role, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :provider, :uid, :name, :avatar_url, :role])
    |> validate_required([:email, :provider, :uid, :name, :avatar_url, :role])
  end
end
