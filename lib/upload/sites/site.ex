defmodule Upload.Sites.Site do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sites" do
    field :name, :string
    field :subdomain, :string
    field :base_domain, :string, default: "nabaleague.com"

    many_to_many :users, Upload.Accounts.User, join_through: Upload.Sites.UserSite

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(site, attrs) do
    site
    |> cast(attrs, [:name, :subdomain, :base_domain])
    |> validate_required([:name, :subdomain])
    |> validate_format(:subdomain, ~r/^[a-z0-9-]+$/,
      message: "must contain only lowercase letters, numbers, and hyphens"
    )
    |> validate_length(:subdomain, min: 1, max: 63)
    |> unique_constraint(:subdomain)
  end

  @doc """
  Returns the full domain for this site.
  """
  def full_domain(%__MODULE__{subdomain: subdomain, base_domain: base_domain}) do
    "#{subdomain}.#{base_domain}"
  end
end
