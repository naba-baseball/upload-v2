defmodule Upload.Sites.Site do
  use Ecto.Schema
  import Ecto.Changeset

  @deployment_statuses ~w(pending deploying deployed failed)

  schema "sites" do
    field :name, :string
    field :subdomain, :string
    field :base_domain, :string, default: "nabaleague.com"

    # Cloudflare deployment fields
    field :cloudflare_worker_name, :string
    field :deployment_status, :string, default: "pending"
    field :last_deployed_at, :utc_datetime
    field :last_deployment_error, :string

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
  Changeset for updating deployment status.
  """
  def deployment_changeset(site, attrs) do
    site
    |> cast(attrs, [
      :cloudflare_worker_name,
      :deployment_status,
      :last_deployed_at,
      :last_deployment_error
    ])
    |> validate_inclusion(:deployment_status, @deployment_statuses)
  end

  @doc """
  Returns the full domain for this site.
  """
  def full_domain(%__MODULE__{subdomain: subdomain, base_domain: base_domain}) do
    "#{subdomain}.#{base_domain}"
  end

  @doc """
  Returns the worker name for this site, generating one if not set.
  """
  def worker_name(%__MODULE__{cloudflare_worker_name: name}) when is_binary(name), do: name
  def worker_name(%__MODULE__{subdomain: subdomain}), do: "upload-site-#{subdomain}"
end
