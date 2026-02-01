defmodule UploadWeb.SiteUploadLiveTest do
  use UploadWeb.ConnCase

  import Phoenix.LiveViewTest
  import Upload.AccountsFixtures
  import Upload.SitesFixtures

  describe "mount" do
    test "redirects when not authenticated", %{conn: conn} do
      site = site_fixture()
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/sites/#{site.id}/upload")
    end

    test "redirects to dashboard when user is not assigned to site", %{conn: conn} do
      user = user_fixture()
      site = site_fixture()
      conn = init_test_session(conn, %{user_id: user.id})

      # Should redirect to dashboard with error flash
      assert {:error, {:live_redirect, %{to: "/dashboard", flash: flash}}} =
               live(conn, ~p"/sites/#{site.id}/upload")

      assert flash["error"] == "You don't have access to this site"
    end

    test "renders upload page when user is assigned to site", %{conn: conn} do
      user = user_fixture()
      site = site_fixture()
      assign_user_to_site(user, site)
      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/sites/#{site.id}/upload")

      assert html =~ "Upload to #{site.name}"
      assert html =~ site.subdomain
    end
  end

  describe "rendering" do
    setup %{conn: conn} do
      user = user_fixture()
      site = site_fixture(%{name: "Test Site", subdomain: "testsite"})
      assign_user_to_site(user, site)
      conn = init_test_session(conn, %{user_id: user.id})

      %{conn: conn, user: user, site: site}
    end

    test "displays site name in heading", %{conn: conn, site: site} do
      {:ok, _view, html} = live(conn, ~p"/sites/#{site.id}/upload")

      assert html =~ "Upload to Test Site"
    end

    test "displays site domain", %{conn: conn, site: site} do
      {:ok, _view, html} = live(conn, ~p"/sites/#{site.id}/upload")
      base_domain = Application.get_env(:upload, :base_domain)

      assert html =~ "testsite.#{base_domain}"
    end

    test "displays back to dashboard link", %{conn: conn, site: site} do
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.id}/upload")

      assert has_element?(view, "a[href='/dashboard']")
      assert render(view) =~ "Back to Dashboard"
    end

    test "displays upload form", %{conn: conn, site: site} do
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.id}/upload")

      assert has_element?(view, "form#upload-form")
      assert has_element?(view, "input[type='file']")
    end

    test "displays upload button", %{conn: conn, site: site} do
      {:ok, _view, html} = live(conn, ~p"/sites/#{site.id}/upload")

      assert html =~ "Upload Archive"
    end

    test "displays file type instruction", %{conn: conn, site: site} do
      {:ok, _view, html} = live(conn, ~p"/sites/#{site.id}/upload")

      assert html =~ ".tar.gz"
    end

    test "submit button is disabled when no file is selected", %{conn: conn, site: site} do
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.id}/upload")

      assert has_element?(view, "button[type='submit'][disabled]")
    end

    test "file input has required attribute", %{conn: conn, site: site} do
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.id}/upload")

      assert has_element?(view, "input[type='file'][required]")
    end
  end

  describe "authorization" do
    test "user can access upload for their assigned site", %{conn: conn} do
      user = user_fixture()
      site = site_fixture()
      assign_user_to_site(user, site)
      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/sites/#{site.id}/upload")

      assert html =~ site.name
    end

    test "user cannot access upload for unassigned site", %{conn: conn} do
      user = user_fixture()
      site = site_fixture()
      # Not assigning user to site
      conn = init_test_session(conn, %{user_id: user.id})

      assert {:error, {:live_redirect, %{to: "/dashboard", flash: flash}}} =
               live(conn, ~p"/sites/#{site.id}/upload")

      assert flash["error"] == "You don't have access to this site"
    end

    test "user with multiple sites can access each", %{conn: conn} do
      user = user_fixture()
      site1 = site_fixture(%{name: "Site One"})
      site2 = site_fixture(%{name: "Site Two"})
      assign_user_to_site(user, site1)
      assign_user_to_site(user, site2)
      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, _view, html1} = live(conn, ~p"/sites/#{site1.id}/upload")
      assert html1 =~ "Site One"

      {:ok, _view, html2} = live(conn, ~p"/sites/#{site2.id}/upload")
      assert html2 =~ "Site Two"
    end

    test "different users can access the same site if both assigned", %{conn: conn} do
      user1 = user_fixture()
      user2 = user_fixture()
      site = site_fixture(%{name: "Shared Site"})
      assign_user_to_site(user1, site)
      assign_user_to_site(user2, site)

      conn1 = init_test_session(conn, %{user_id: user1.id})
      {:ok, _view, html1} = live(conn1, ~p"/sites/#{site.id}/upload")
      assert html1 =~ "Shared Site"

      conn2 = init_test_session(build_conn(), %{user_id: user2.id})
      {:ok, _view, html2} = live(conn2, ~p"/sites/#{site.id}/upload")
      assert html2 =~ "Shared Site"
    end
  end

  describe "real-time deployment updates" do
    setup %{conn: conn} do
      user = user_fixture()
      site = site_fixture(%{name: "Test Site", subdomain: "testsite"})
      assign_user_to_site(user, site)
      conn = init_test_session(conn, %{user_id: user.id})

      %{conn: conn, user: user, site: site}
    end

    test "updates UI when deployment status changes to deployed", %{conn: conn, site: site} do
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.id}/upload")

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
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.id}/upload")

      # Simulate a deployment failure via PubSub
      updated_site = %{
        site
        | deployment_status: "failed",
          last_deployment_error: "Test error message"
      }

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
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.id}/upload")

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
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.id}/upload")

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
      {:ok, view, _html} = live(conn, ~p"/sites/#{site.id}/upload")

      error_message = "Network error during deployment"
      updated_site = %{site | deployment_status: "failed", last_deployment_error: error_message}

      Phoenix.PubSub.broadcast(
        Upload.PubSub,
        "site:#{site.id}",
        {:deployment_updated, updated_site}
      )

      # Check for error flash with the error message
      assert render(view) =~ error_message
    end
  end
end
