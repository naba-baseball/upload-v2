defmodule UploadWeb.DashboardLiveTest do
  use UploadWeb.ConnCase

  import Phoenix.LiveViewTest
  import Upload.AccountsFixtures
  import Upload.SitesFixtures

  describe "mount" do
    test "redirects when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/dashboard")
    end

    test "renders dashboard when authenticated", %{conn: conn} do
      user = user_fixture()
      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Welcome"
      assert html =~ user.name
    end

    test "loads user with sites preloaded", %{conn: conn} do
      user = user_fixture()
      site1 = site_fixture()
      site2 = site_fixture()
      assign_user_to_site(user, site1)
      assign_user_to_site(user, site2)

      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Verify sites are displayed
      assert render(view) =~ site1.name
      assert render(view) =~ site2.name
    end
  end

  describe "rendering" do
    test "displays user welcome message", %{conn: conn} do
      user = user_fixture()
      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Welcome, #{user.name}!"
      assert html =~ "Your personal dashboard"
    end

    test "displays all assigned sites", %{conn: conn} do
      user = user_fixture()
      site1 = site_fixture(%{name: "First Site"})
      site2 = site_fixture(%{name: "Second Site"})
      assign_user_to_site(user, site1)
      assign_user_to_site(user, site2)

      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "First Site"
      assert html =~ "Second Site"
    end

    test "each site shows name and URL", %{conn: conn} do
      user = user_fixture()
      site = site_fixture(%{name: "Test Site", subdomain: "testsite"})
      assign_user_to_site(user, site)
      base_domain = Application.get_env(:upload, :base_domain)

      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Test Site"
      assert html =~ "testsite.#{base_domain}"
    end

    test "shows empty state when user has no sites", %{conn: conn} do
      user = user_fixture()
      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "haven&#39;t been assigned to any sites yet"
      assert html =~ "contact an administrator"
    end

    test "shows heading 'Your Sites'", %{conn: conn} do
      user = user_fixture()
      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Your Sites"
    end

    test "site URLs open in new tab", %{conn: conn} do
      user = user_fixture()
      site = site_fixture()
      assign_user_to_site(user, site)

      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ ~s(target="_blank")
      assert html =~ ~s(rel="noopener noreferrer")
    end

    test "displays user account information", %{conn: conn} do
      user = user_fixture()
      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Account Information"
      assert html =~ user.name
      assert html =~ user.email
      assert html =~ user.avatar_url
    end
  end

  describe "admin users" do
    test "shows admin banner for admin users", %{conn: conn} do
      admin = admin_fixture()
      conn = init_test_session(conn, %{user_id: admin.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Admin Access"
      assert html =~ "Go to Admin Panel"
    end

    test "does not show admin banner for regular users", %{conn: conn} do
      user = user_fixture()
      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      refute html =~ "Admin Access"
      refute html =~ "Go to Admin Panel"
    end

    test "admin panel link points to correct route", %{conn: conn} do
      admin = admin_fixture()
      conn = init_test_session(conn, %{user_id: admin.id})

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "a[href='/admin/sites']")
    end
  end

  describe "multiple sites layout" do
    test "displays sites in a grid for multiple sites", %{conn: conn} do
      user = user_fixture()
      site1 = site_fixture()
      site2 = site_fixture()
      site3 = site_fixture()
      assign_user_to_site(user, site1)
      assign_user_to_site(user, site2)
      assign_user_to_site(user, site3)

      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Check for grid layout classes
      assert html =~ "grid"
      assert html =~ "gap-4"
    end

    test "each site is a separate card", %{conn: conn} do
      user = user_fixture()
      site1 = site_fixture(%{name: "Site 1"})
      site2 = site_fixture(%{name: "Site 2"})
      assign_user_to_site(user, site1)
      assign_user_to_site(user, site2)

      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      # Verify both sites are rendered
      assert html =~ "Site 1"
      assert html =~ "Site 2"
      # Check for card styling
      assert html =~ "border-indigo"
    end
  end

  describe "single site upload" do
    test "shows upload form inline when user has exactly 1 site", %{conn: conn} do
      user = user_fixture()
      site = site_fixture(%{name: "Solo Site"})
      assign_user_to_site(user, site)

      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, view, html} = live(conn, ~p"/dashboard")

      # Should show site name but not the "Your Sites" heading
      assert html =~ "Solo Site"
      refute html =~ "Your Sites"

      # Should show upload form inline
      assert html =~ "Upload Site Archive"
      assert has_element?(view, "form#upload-form")
      assert has_element?(view, "input[type='file']")
    end

    test "upload button is disabled when no file selected for single site", %{conn: conn} do
      user = user_fixture()
      site = site_fixture()
      assign_user_to_site(user, site)

      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "button[type='submit'][disabled]")
    end

    test "shows site cards when user has multiple sites", %{conn: conn} do
      user = user_fixture()
      site1 = site_fixture(%{name: "First Site"})
      site2 = site_fixture(%{name: "Second Site"})
      assign_user_to_site(user, site1)
      assign_user_to_site(user, site2)

      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, view, html} = live(conn, ~p"/dashboard")

      # Should show "Your Sites" heading
      assert html =~ "Your Sites"

      # Should NOT show inline upload form
      refute html =~ "Upload Site Archive"
      refute has_element?(view, "form#upload-form")

      # Should show site cards with upload links
      assert html =~ "First Site"
      assert html =~ "Second Site"
      assert has_element?(view, "a[href='/sites/#{site1.id}/upload']")
    end

    test "file input is required for single site upload", %{conn: conn} do
      user = user_fixture()
      site = site_fixture()
      assign_user_to_site(user, site)

      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "input[type='file'][required]")
    end
  end

  describe "real-time deployment updates for single site" do
    setup %{conn: conn} do
      user = user_fixture()
      site = site_fixture(%{name: "Solo Site", subdomain: "solosite"})
      assign_user_to_site(user, site)
      conn = init_test_session(conn, %{user_id: user.id})

      %{conn: conn, user: user, site: site}
    end

    test "updates UI when deployment status changes to deployed", %{conn: conn, site: site} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Simulate a deployment update via PubSub
      updated_site = %{site | deployment_status: "deployed", last_deployed_at: DateTime.utc_now()}

      Phoenix.PubSub.broadcast(
        Upload.PubSub,
        "site:#{site.id}",
        {:deployment_updated, updated_site}
      )

      # Wait for the update to be processed and check the HTML
      html = render(view)
      assert html =~ "Deployed"
    end

    test "updates UI when deployment status changes to failed", %{conn: conn, site: site} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Simulate a deployment failure via PubSub
      updated_site = %{site | deployment_status: "failed", last_deployment_error: "Test error"}

      Phoenix.PubSub.broadcast(
        Upload.PubSub,
        "site:#{site.id}",
        {:deployment_updated, updated_site}
      )

      # Wait for the update to be processed and check the HTML
      html = render(view)
      assert html =~ "Failed"
    end

    test "updates UI when deployment status changes to deploying", %{conn: conn, site: site} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Simulate deployment starting via PubSub
      updated_site = %{site | deployment_status: "deploying"}

      Phoenix.PubSub.broadcast(
        Upload.PubSub,
        "site:#{site.id}",
        {:deployment_updated, updated_site}
      )

      # Wait for the update to be processed and check the HTML
      html = render(view)
      assert html =~ "Deploying"
    end

    test "shows success flash when deployment succeeds", %{conn: conn, site: site} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      updated_site = %{site | deployment_status: "deployed", last_deployed_at: DateTime.utc_now()}

      Phoenix.PubSub.broadcast(
        Upload.PubSub,
        "site:#{site.id}",
        {:deployment_updated, updated_site}
      )

      # Check for success flash
      assert render(view) =~ "Deployment successful!"
    end

    test "shows error flash when deployment fails", %{conn: conn, site: site} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      error_message = "Archive contained no valid site files"
      updated_site = %{site | deployment_status: "failed", last_deployment_error: error_message}

      Phoenix.PubSub.broadcast(
        Upload.PubSub,
        "site:#{site.id}",
        {:deployment_updated, updated_site}
      )

      # Check for error flash with the error message
      assert render(view) =~ error_message
    end

    test "updates both single_site and sites assigns", %{conn: conn, site: site} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      # Simulate a deployment update via PubSub
      updated_site = %{site | deployment_status: "deployed", last_deployed_at: DateTime.utc_now()}

      Phoenix.PubSub.broadcast(
        Upload.PubSub,
        "site:#{site.id}",
        {:deployment_updated, updated_site}
      )

      # The page should still show the site correctly after update
      html = render(view)
      assert html =~ "Solo Site"
      assert html =~ "Deployed"
    end
  end
end
