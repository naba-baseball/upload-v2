defmodule UploadWeb.Admin.UsersLiveTest do
  use UploadWeb.ConnCase

  import Phoenix.LiveViewTest
  import Upload.AccountsFixtures
  import Upload.SitesFixtures

  alias Upload.Sites

  describe "mount" do
    test "redirects when not authenticated", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/users")
    end

    test "redirects when authenticated as regular user", %{conn: conn} do
      user = user_fixture()
      conn = init_test_session(conn, %{user_id: user.id})

      assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin/users")
    end

    test "renders for admin users", %{conn: conn} do
      admin = admin_fixture()
      conn = init_test_session(conn, %{user_id: admin.id})

      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ "Assign Users to Sites"
    end

    test "loads users with sites preloaded", %{conn: conn} do
      admin = admin_fixture()
      user = user_fixture()
      site = site_fixture()
      assign_user_to_site(user, site)

      conn = init_test_session(conn, %{user_id: admin.id})

      {:ok, view, _html} = live(conn, ~p"/admin/users")

      # Verify user is displayed with their site
      assert has_element?(view, "[id^='users-#{user.id}']")
    end

    test "loads all sites", %{conn: conn} do
      admin = admin_fixture()
      site1 = site_fixture()
      site2 = site_fixture()

      conn = init_test_session(conn, %{user_id: admin.id})

      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ site1.name
      assert html =~ site2.name
    end
  end

  describe "toggle_user_site event" do
    test "adds user to site when not assigned", %{conn: conn} do
      admin = admin_fixture()
      user = user_fixture()
      site = site_fixture()

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      refute Sites.user_assigned_to_site?(user.id, site.id)

      view
      |> element(
        "button[phx-click='toggle_user_site'][phx-value-user-id='#{user.id}'][phx-value-site-id='#{site.id}']"
      )
      |> render_click()

      assert Sites.user_assigned_to_site?(user.id, site.id)
      assert render(view) =~ "User site assignment updated"
    end

    test "removes user from site when already assigned", %{conn: conn} do
      admin = admin_fixture()
      user = user_fixture()
      site = site_fixture()
      assign_user_to_site(user, site)

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert Sites.user_assigned_to_site?(user.id, site.id)

      view
      |> element(
        "button[phx-click='toggle_user_site'][phx-value-user-id='#{user.id}'][phx-value-site-id='#{site.id}']"
      )
      |> render_click()

      refute Sites.user_assigned_to_site?(user.id, site.id)
      assert render(view) =~ "User site assignment updated"
    end

    test "allows toggling multiple sites for one user", %{conn: conn} do
      admin = admin_fixture()
      user = user_fixture()
      site1 = site_fixture()
      site2 = site_fixture()

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      # Assign to site1
      view
      |> element(
        "button[phx-click='toggle_user_site'][phx-value-user-id='#{user.id}'][phx-value-site-id='#{site1.id}']"
      )
      |> render_click()

      # Assign to site2
      view
      |> element(
        "button[phx-click='toggle_user_site'][phx-value-user-id='#{user.id}'][phx-value-site-id='#{site2.id}']"
      )
      |> render_click()

      assert Sites.user_assigned_to_site?(user.id, site1.id)
      assert Sites.user_assigned_to_site?(user.id, site2.id)
    end

    test "updates stream with fresh user data", %{conn: conn} do
      admin = admin_fixture()
      user = user_fixture()
      site = site_fixture()

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      view
      |> element(
        "button[phx-click='toggle_user_site'][phx-value-user-id='#{user.id}'][phx-value-site-id='#{site.id}']"
      )
      |> render_click()

      # The view should show the updated state with the site assigned
      html = render(view)
      assert html =~ site.name
    end
  end

  describe "rendering" do
    test "displays all users in table", %{conn: conn} do
      admin = admin_fixture()
      user1 = user_fixture()
      user2 = user_fixture()

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ user1.name
      assert html =~ user1.email
      assert html =~ user2.name
      assert html =~ user2.email
    end

    test "shows site toggle buttons for each user", %{conn: conn} do
      admin = admin_fixture()
      user = user_fixture()
      site = site_fixture()

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      assert has_element?(
               view,
               "button[phx-click='toggle_user_site'][phx-value-user-id='#{user.id}'][phx-value-site-id='#{site.id}']"
             )
    end

    test "shows visual indicator for assigned sites", %{conn: conn} do
      admin = admin_fixture()
      user = user_fixture()
      site = site_fixture()
      assign_user_to_site(user, site)

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, view, _html} = live(conn, ~p"/admin/users")

      html = render(view)

      # The assigned site button should have different styling
      assert html =~ site.name
      # Check for the check icon or similar visual indicator
      assert html =~ "hero-check"
    end

    test "shows 'No sites assigned' when user has no sites", %{conn: conn} do
      admin = admin_fixture()
      _user = user_fixture()

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ "No sites assigned"
    end

    test "displays user avatars", %{conn: conn} do
      admin = admin_fixture()
      user = user_fixture()

      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, _view, html} = live(conn, ~p"/admin/users")

      assert html =~ user.avatar_url
    end
  end
end
