defmodule Upload.SitesTest do
  use Upload.DataCase

  import Upload.SitesFixtures
  import Upload.AccountsFixtures

  alias Upload.Sites

  describe "list_sites/0" do
    test "returns all sites" do
      site1 = site_fixture()
      site2 = site_fixture()

      sites = Sites.list_sites()

      assert length(sites) == 2
      assert Enum.any?(sites, &(&1.id == site1.id))
      assert Enum.any?(sites, &(&1.id == site2.id))
    end

    test "returns empty list when no sites exist" do
      assert Sites.list_sites() == []
    end
  end

  describe "get_site!/1" do
    test "returns the site with given id" do
      site = site_fixture()
      fetched_site = Sites.get_site!(site.id)

      assert fetched_site.id == site.id
      assert fetched_site.name == site.name
      assert fetched_site.subdomain == site.subdomain
    end

    test "raises Ecto.NoResultsError when site does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Sites.get_site!(999_999)
      end
    end
  end

  describe "create_site/1" do
    test "creates a site with valid attributes" do
      attrs = %{
        name: "Test Site",
        subdomain: "testsite"
      }

      assert {:ok, site} = Sites.create_site(attrs)
      assert site.name == "Test Site"
      assert site.subdomain == "testsite"
    end

    test "returns error with invalid subdomain format" do
      attrs = %{name: "Test Site", subdomain: "Test Site!"}

      assert {:error, changeset} = Sites.create_site(attrs)

      assert "must contain only lowercase letters, numbers, and hyphens" in errors_on(changeset).subdomain
    end

    test "returns error with duplicate subdomain" do
      site_fixture(%{subdomain: "duplicate"})
      attrs = %{name: "Another Site", subdomain: "duplicate"}

      assert {:error, changeset} = Sites.create_site(attrs)
      assert "has already been taken" in errors_on(changeset).subdomain
    end

    test "returns error when required fields are missing" do
      assert {:error, changeset} = Sites.create_site(%{})
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).subdomain
    end
  end

  describe "update_site/2" do
    test "updates the site with valid attributes" do
      site = site_fixture()
      attrs = %{name: "Updated Name"}

      assert {:ok, updated_site} = Sites.update_site(site, attrs)
      assert updated_site.name == "Updated Name"
      assert updated_site.id == site.id
    end

    test "returns error with invalid attributes" do
      site = site_fixture()
      attrs = %{subdomain: "Invalid Subdomain!"}

      assert {:error, changeset} = Sites.update_site(site, attrs)

      assert "must contain only lowercase letters, numbers, and hyphens" in errors_on(changeset).subdomain
    end
  end

  describe "delete_site/1" do
    test "deletes the site" do
      site = site_fixture()

      assert {:ok, deleted_site} = Sites.delete_site(site)
      assert deleted_site.id == site.id
      assert_raise Ecto.NoResultsError, fn -> Sites.get_site!(site.id) end
    end

    test "deletes all user_sites when site is deleted (cascade)" do
      site = site_fixture()
      user = user_fixture()

      Sites.add_user_to_site(user.id, site.id)
      assert Sites.user_assigned_to_site?(user.id, site.id)

      {:ok, _} = Sites.delete_site(site)

      # Verify the user_site join record is deleted
      refute Sites.user_assigned_to_site?(user.id, site.id)
    end
  end

  describe "add_user_to_site/2" do
    test "assigns a user to a site" do
      user = user_fixture()
      site = site_fixture()

      assert {:ok, _user_site} = Sites.add_user_to_site(user.id, site.id)
      assert Sites.user_assigned_to_site?(user.id, site.id)
    end

    test "is idempotent - adding same user to same site twice doesn't fail" do
      user = user_fixture()
      site = site_fixture()

      assert {:ok, _} = Sites.add_user_to_site(user.id, site.id)
      assert {:ok, _} = Sites.add_user_to_site(user.id, site.id)

      # User should only be assigned once
      site_users = Sites.list_site_users(site.id)
      assert length(site_users) == 1
    end

    test "allows a user to be assigned to multiple sites" do
      user = user_fixture()
      site1 = site_fixture()
      site2 = site_fixture()

      Sites.add_user_to_site(user.id, site1.id)
      Sites.add_user_to_site(user.id, site2.id)

      assert Sites.user_assigned_to_site?(user.id, site1.id)
      assert Sites.user_assigned_to_site?(user.id, site2.id)
    end

    test "allows multiple users to be assigned to one site" do
      user1 = user_fixture()
      user2 = user_fixture()
      site = site_fixture()

      Sites.add_user_to_site(user1.id, site.id)
      Sites.add_user_to_site(user2.id, site.id)

      site_users = Sites.list_site_users(site.id)
      assert length(site_users) == 2
    end
  end

  describe "remove_user_from_site/2" do
    test "removes a user from a site" do
      user = user_fixture()
      site = site_fixture()
      Sites.add_user_to_site(user.id, site.id)

      assert Sites.remove_user_from_site(user.id, site.id) == :ok
      refute Sites.user_assigned_to_site?(user.id, site.id)
    end

    test "is safe when user is not assigned to site" do
      user = user_fixture()
      site = site_fixture()

      # Should not raise an error
      assert Sites.remove_user_from_site(user.id, site.id) == :ok
    end

    test "only removes assignment from specified site" do
      user = user_fixture()
      site1 = site_fixture()
      site2 = site_fixture()

      Sites.add_user_to_site(user.id, site1.id)
      Sites.add_user_to_site(user.id, site2.id)

      Sites.remove_user_from_site(user.id, site1.id)

      refute Sites.user_assigned_to_site?(user.id, site1.id)
      assert Sites.user_assigned_to_site?(user.id, site2.id)
    end
  end

  describe "toggle_user_site/2" do
    test "adds user to site when not assigned" do
      user = user_fixture()
      site = site_fixture()

      refute Sites.user_assigned_to_site?(user.id, site.id)

      assert {:ok, updated_user} = Sites.toggle_user_site(user.id, site.id)
      assert Sites.user_assigned_to_site?(user.id, site.id)

      # Verify user is returned with sites preloaded
      assert Ecto.assoc_loaded?(updated_user.sites)
      assert Enum.any?(updated_user.sites, &(&1.id == site.id))
    end

    test "removes user from site when already assigned" do
      user = user_fixture()
      site = site_fixture()
      Sites.add_user_to_site(user.id, site.id)

      assert Sites.user_assigned_to_site?(user.id, site.id)

      assert {:ok, updated_user} = Sites.toggle_user_site(user.id, site.id)
      refute Sites.user_assigned_to_site?(user.id, site.id)

      # Verify user is returned with sites preloaded
      assert Ecto.assoc_loaded?(updated_user.sites)
      refute Enum.any?(updated_user.sites, &(&1.id == site.id))
    end

    test "forces preload refresh to get latest data" do
      user = user_fixture()
      site1 = site_fixture()
      site2 = site_fixture()

      Sites.add_user_to_site(user.id, site1.id)

      {:ok, updated_user} = Sites.toggle_user_site(user.id, site2.id)

      # Should have both sites
      assert length(updated_user.sites) == 2
    end
  end

  describe "user_assigned_to_site?/2" do
    test "returns true when user is assigned to site" do
      user = user_fixture()
      site = site_fixture()
      Sites.add_user_to_site(user.id, site.id)

      assert Sites.user_assigned_to_site?(user.id, site.id)
    end

    test "returns false when user is not assigned to site" do
      user = user_fixture()
      site = site_fixture()

      refute Sites.user_assigned_to_site?(user.id, site.id)
    end
  end

  describe "list_site_users/1" do
    test "returns all users assigned to a site" do
      user1 = user_fixture()
      user2 = user_fixture()
      site = site_fixture()

      Sites.add_user_to_site(user1.id, site.id)
      Sites.add_user_to_site(user2.id, site.id)

      users = Sites.list_site_users(site.id)

      assert length(users) == 2
      assert Enum.any?(users, &(&1.id == user1.id))
      assert Enum.any?(users, &(&1.id == user2.id))
    end

    test "returns empty list when no users assigned" do
      site = site_fixture()

      assert Sites.list_site_users(site.id) == []
    end

    test "preloads users association" do
      user = user_fixture()
      site = site_fixture()
      Sites.add_user_to_site(user.id, site.id)

      [fetched_user] = Sites.list_site_users(site.id)

      # Verify it's a User struct
      assert fetched_user.__struct__ == Upload.Accounts.User
    end
  end

  describe "deployment status functions" do
    test "mark_deploying/1 sets status to deploying and clears error" do
      site = site_fixture()

      {:ok, updated_site} = Sites.mark_deploying(site)

      assert updated_site.deployment_status == "deploying"
      assert updated_site.last_deployment_error == nil
    end

    test "mark_deployed/1 sets status to deployed and updates timestamp" do
      site = site_fixture()

      {:ok, updated_site} = Sites.mark_deployed(site)

      assert updated_site.deployment_status == "deployed"
      assert updated_site.last_deployed_at != nil
      assert updated_site.last_deployment_error == nil
    end

    test "mark_deployment_failed/2 sets status to failed and stores formatted error" do
      site = site_fixture()

      {:ok, updated_site} = Sites.mark_deployment_failed(site, :no_html_files)

      assert updated_site.deployment_status == "failed"
      assert updated_site.last_deployment_error =~ "must contain at least one HTML file"
    end

    test "mark_deploying/1 broadcasts via PubSub" do
      site = site_fixture()
      Phoenix.PubSub.subscribe(Upload.PubSub, "site:#{site.id}")

      {:ok, updated_site} = Sites.mark_deploying(site)

      assert_receive {:deployment_updated, ^updated_site}
    end

    test "mark_deployed/1 broadcasts via PubSub" do
      site = site_fixture()
      Phoenix.PubSub.subscribe(Upload.PubSub, "site:#{site.id}")

      {:ok, updated_site} = Sites.mark_deployed(site)

      assert_receive {:deployment_updated, ^updated_site}
    end

    test "mark_deployment_failed/2 broadcasts via PubSub" do
      site = site_fixture()
      Phoenix.PubSub.subscribe(Upload.PubSub, "site:#{site.id}")

      {:ok, updated_site} = Sites.mark_deployment_failed(site, :some_error)

      assert_receive {:deployment_updated, ^updated_site}
    end
  end

  describe "format_deployment_error/1" do
    test "formats extraction_failed with string output" do
      error = {:extraction_failed, "tar: invalid archive\n"}

      result = Sites.format_deployment_error(error)

      assert result == "Failed to extract archive: tar: invalid archive"
    end

    test "formats extraction_failed with non-string reason" do
      error = {:extraction_failed, :enoent}

      result = Sites.format_deployment_error(error)

      assert result == "Failed to extract archive: :enoent"
    end

    test "formats file_stat_failed" do
      error = {:file_stat_failed, :enoent}

      result = Sites.format_deployment_error(error)

      assert result =~ "Failed to read archive file"
      assert result =~ ":enoent"
    end

    test "formats file_too_large" do
      error = {:file_too_large, 600_000_000, 524_288_000}

      result = Sites.format_deployment_error(error)

      assert result =~ "Archive too large"
      assert result =~ "MB"
    end

    test "formats decompressed_too_large" do
      error = {:decompressed_too_large, 2_000_000_000, 1_073_741_824}

      result = Sites.format_deployment_error(error)

      assert result =~ "Decompressed archive too large"
      assert result =~ "GB"
    end

    test "formats gzip_decompression_failed" do
      error = {:gzip_decompression_failed, "data error"}

      result = Sites.format_deployment_error(error)

      assert result =~ "Failed to decompress archive"
      assert result =~ "invalid or corrupted"
    end

    test "formats no_html_files" do
      result = Sites.format_deployment_error(:no_html_files)

      assert result =~ "must contain at least one HTML file"
      assert result =~ "index.html"
    end

    test "formats path_traversal_detected" do
      error = {:path_traversal_detected, "/tmp/extract/../../../etc/passwd"}

      result = Sites.format_deployment_error(error)

      assert result =~ "Invalid archive"
      assert result =~ "unsafe file paths"
    end

    test "formats unknown errors generically (logs details, hides from user)" do
      error = {:unknown_error, :something_weird}

      result = Sites.format_deployment_error(error)

      # User sees a generic message (doesn't expose internal details)
      assert result == "Deployment failed: unknown error"
      # Details are logged for debugging (verified via Logger.warning call)
    end
  end
end
