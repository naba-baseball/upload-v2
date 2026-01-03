defmodule Upload.Sites do
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

  @doc """
  Gets a single site.
  Raises if the site is not found.
  """
  def get_site!(id), do: Repo.get!(Site, id)

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
    Repo.delete(site)
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
    update_deployment_status(site, %{
      deployment_status: "deploying",
      last_deployment_error: nil
    })
  end

  @doc """
  Marks a site as successfully deployed.
  """
  def mark_deployed(%Site{} = site) do
    update_deployment_status(site, %{
      deployment_status: "deployed",
      last_deployed_at: DateTime.utc_now(),
      last_deployment_error: nil
    })
  end

  @doc """
  Marks a site deployment as failed.
  """
  def mark_deployment_failed(%Site{} = site, error) do
    update_deployment_status(site, %{
      deployment_status: "failed",
      last_deployment_error: inspect(error)
    })
  end

  @doc """
  Sets the worker name for a site.
  """
  def set_worker_name(%Site{} = site, worker_name) do
    update_deployment_status(site, %{cloudflare_worker_name: worker_name})
  end
end
