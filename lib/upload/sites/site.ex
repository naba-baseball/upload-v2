defmodule Upload.Sites.Site do
  use Ecto.Schema
  import Ecto.Changeset

  @deployment_statuses ~w(pending deploying deployed failed)
  @routing_modes ~w(subdomain subpath both)

  schema "sites" do
    field :name, :string
    field :subdomain, :string
    field :routing_mode, :string, default: "subdomain"

    # Deployment fields
    field :deployment_status, :string, default: "pending"
    field :last_deployed_at, :utc_datetime
    field :last_deployment_error, :string

    many_to_many :users, Upload.Accounts.User, join_through: Upload.Sites.UserSite

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(site, attrs) do
    site
    |> cast(attrs, [:name, :subdomain, :routing_mode])
    |> validate_required([:name, :subdomain])
    |> validate_format(:subdomain, ~r/^[a-z0-9-]+$/,
      message: "must contain only lowercase letters, numbers, and hyphens"
    )
    |> validate_length(:subdomain, min: 1, max: 63)
    |> validate_inclusion(:routing_mode, @routing_modes)
    |> unique_constraint(:subdomain)
  end

  @doc """
  Changeset for updating deployment status.
  """
  def deployment_changeset(site, attrs) do
    site
    |> cast(attrs, [
      :deployment_status,
      :last_deployed_at,
      :last_deployment_error
    ])
    |> validate_inclusion(:deployment_status, @deployment_statuses)
  end

  @doc """
  Returns the full domain for this site.
  """
  def full_domain(%__MODULE__{subdomain: subdomain}) do
    base_domain = Application.get_env(:upload, :base_domain)
    "#{subdomain}.#{base_domain}"
  end

  @doc """
  Returns the subpath for this site.
  """
  def subpath(%__MODULE__{subdomain: subdomain}) do
    "/sites/#{subdomain}"
  end

  @doc """
  Returns a formatted URL for the site based on the specified format.
  Uses http:// for localhost domains, https:// otherwise.

  ## Examples

      iex> format_site_url(site, :subdomain)
      "https://mysite.example.com"

      iex> format_site_url(site, :subpath)
      "https://example.com/sites/mysite"

  """
  def format_site_url(%__MODULE__{} = site, :subdomain) do
    "#{url_scheme()}#{full_domain(site)}"
  end

  def format_site_url(%__MODULE__{} = site, :subpath) do
    base_domain = Application.get_env(:upload, :base_domain)
    "#{url_scheme()}#{base_domain}#{subpath(site)}"
  end

  def format_site_url(%__MODULE__{} = site) do
    case site.routing_mode do
      "subpath" -> format_site_url(site, :subpath)
      "subdomain" -> format_site_url(site, :subdomain)
    end
  end

  @doc """
  Returns the URL scheme based on the base domain.
  Returns "http://" for localhost, "https://" otherwise.
  """
  def url_scheme do
    base_domain = Application.get_env(:upload, :base_domain)

    if String.starts_with?(base_domain ,"localhost") do
      "http://"
    else
      "https://"
    end
  end
end
