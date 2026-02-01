defmodule Upload.Sites do
  require Logger
  import Ecto.Query, warn: false
  alias Upload.Repo
  alias Upload.Sites.Site
  alias Upload.Sites.UserSite

  @doc """
  Lists all sites.
  """
  def list_sites do
    Repo.all(Site)
  end

  def site_dir(%Site{} = site),
    do: Path.join([:code.priv_dir(:upload), "static", "sites", site.subdomain])

  @doc """
  Gets a single site.
  Raises if the site is not found.
  """
  def get_site!(id), do: Repo.get!(Site, id)

  @doc """
  Gets a site by subdomain.
  Returns nil if the site is not found.
  """
  def get_site_by_subdomain(subdomain) do
    Repo.get_by(Site, subdomain: subdomain)
  end

  @doc """
  Creates a site.
  """
  def create_site(attrs \\ %{}) do
    %Site{}
    |> Site.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a site.
  """
  def update_site(%Site{} = site, attrs) do
    site
    |> Site.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a site.
  """
  def delete_site(%Site{} = site) do
    result = Repo.delete(site)
    # remove site from sites directory
    site_dir(site)
    |> File.rm_rf!()

    result
  end

  @doc """
  Gets all users assigned to a site.
  """
  def list_site_users(site_id) do
    site = Repo.get!(Site, site_id) |> Repo.preload(:users)
    site.users
  end

  @doc """
  Adds a user to a site.
  Returns {:ok, user_site} or {:ok, nil} if already exists.
  """
  def add_user_to_site(user_id, site_id) do
    %UserSite{}
    |> UserSite.changeset(%{})
    |> Ecto.Changeset.put_change(:user_id, user_id)
    |> Ecto.Changeset.put_change(:site_id, site_id)
    |> Repo.insert(on_conflict: :nothing)
  end

  @doc """
  Removes a user from a site.
  """
  def remove_user_from_site(user_id, site_id) do
    from(us in UserSite, where: us.user_id == ^user_id and us.site_id == ^site_id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Toggles a user's assignment to a site.
  If user is assigned, removes them. If not assigned, adds them.
  Returns the updated user with sites preloaded.
  """
  def toggle_user_site(user_id, site_id) do
    query = from(us in UserSite, where: us.user_id == ^user_id and us.site_id == ^site_id)

    case Repo.one(query) do
      nil ->
        add_user_to_site(user_id, site_id)

      _user_site ->
        remove_user_from_site(user_id, site_id)
    end

    user =
      Upload.Accounts.User
      |> Repo.get!(user_id)
      |> Repo.preload(:sites, force: true)

    {:ok, user}
  end

  @doc """
  Checks if a user is assigned to a site.
  """
  def user_assigned_to_site?(user_id, site_id) do
    query = from(us in UserSite, where: us.user_id == ^user_id and us.site_id == ^site_id)
    Repo.exists?(query)
  end

  @doc """
  Updates a site's deployment status.
  """
  def update_deployment_status(%Site{} = site, attrs) do
    site
    |> Site.deployment_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Marks a site as deploying.
  """
  def mark_deploying(%Site{} = site) do
    site
    |> update_deployment_status(%{
      deployment_status: "deploying",
      last_deployment_error: nil
    })
    |> broadcast_deployment_update()
  end

  @doc """
  Marks a site as successfully deployed.
  """
  def mark_deployed(%Site{} = site) do
    site
    |> update_deployment_status(%{
      deployment_status: "deployed",
      last_deployed_at: DateTime.utc_now(),
      last_deployment_error: nil
    })
    |> broadcast_deployment_update()
  end

  @doc """
  Marks a site deployment as failed.
  """
  def mark_deployment_failed(%Site{} = site, error) do
    site
    |> update_deployment_status(%{
      deployment_status: "failed",
      last_deployment_error: format_deployment_error(error)
    })
    |> broadcast_deployment_update()
  end

  # Broadcasts deployment status updates via PubSub
  defp broadcast_deployment_update({:ok, %Site{} = site}) do
    Phoenix.PubSub.broadcast(Upload.PubSub, "site:#{site.id}", {:deployment_updated, site})
    {:ok, site}
  end

  defp broadcast_deployment_update(error), do: error

  @doc """
  Formats a deployment error into a user-friendly message.
  """
  def format_deployment_error({:extraction_failed, output}) when is_binary(output) do
    "Failed to extract archive: #{String.trim(output)}"
  end

  def format_deployment_error({:extraction_failed, reason}) do
    "Failed to extract archive: #{inspect(reason)}"
  end

  def format_deployment_error({:file_stat_failed, reason}) do
    "Failed to read archive file: #{inspect(reason)}"
  end

  def format_deployment_error({:file_too_large, size, max}) do
    "Archive too large: #{format_bytes(size)} exceeds #{format_bytes(max)} limit"
  end

  def format_deployment_error({:decompressed_too_large, size, max}) do
    "Decompressed archive too large: #{format_bytes(size)} exceeds #{format_bytes(max)} limit"
  end

  def format_deployment_error({:gzip_decompression_failed, _reason}) do
    "Failed to decompress archive: invalid or corrupted gzip file"
  end

  def format_deployment_error({:file_write_failed, _path, _reason}) do
    "Failed to write extracted files: insufficient disk space or permission denied"
  end

  def format_deployment_error(:no_html_files) do
    "Archive must contain at least one HTML file (index.html or *.html)"
  end

  def format_deployment_error({:path_traversal_detected, _path}) do
    "Invalid archive: contains unsafe file paths"
  end

  # Catch-all for unexpected errors - log for debugging but show generic message to user
  def format_deployment_error(error) do
    Logger.warning("Unexpected deployment error: #{inspect(error)}")
    "Deployment failed: unknown error"
  end

  def format_deployment_error() do
    "Deployment failed: unknown error"
  end

  defp format_bytes(bytes) when bytes >= 1_073_741_824 do
    "#{Float.round(bytes / 1_073_741_824, 1)} GB"
  end

  defp format_bytes(bytes) when bytes >= 1_048_576 do
    "#{Float.round(bytes / 1_048_576, 1)} MB"
  end

  defp format_bytes(bytes) do
    "#{bytes} bytes"
  end
end
