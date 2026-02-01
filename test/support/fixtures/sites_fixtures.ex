defmodule Upload.SitesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Upload.Sites` context.
  """

  alias Upload.Repo
  alias Upload.Sites

  @doc """
  Generate a unique site.
  """
  def site_fixture(attrs \\ %{}) do
    unique_num = System.unique_integer([:positive])

    attrs =
      Enum.into(attrs, %{
        name: "Test Site #{unique_num}",
        subdomain: "testsite#{unique_num}"
      })

    {:ok, site} = Sites.create_site(attrs)
    site
  end

  @doc """
  Assign a user to a site.
  """
  def assign_user_to_site(user, site) do
    Sites.add_user_to_site(user.id, site.id)
    Repo.preload(user, :sites, force: true)
  end

  @doc """
  Create a site with users already assigned.
  """
  def site_with_users_fixture(users) when is_list(users) do
    site = site_fixture()

    Enum.each(users, fn user ->
      Sites.add_user_to_site(user.id, site.id)
    end)

    Repo.preload(site, :users)
  end
end
