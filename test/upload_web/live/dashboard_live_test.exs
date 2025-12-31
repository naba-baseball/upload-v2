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

      conn = init_test_session(conn, %{user_id: user.id})

      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Test Site"
      assert html =~ "testsite.nabaleague.com"
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
end
