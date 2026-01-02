defmodule UploadWeb.UserAuthTest do
  use UploadWeb.ConnCase, async: true

  alias Upload.AccountsFixtures
  alias UploadWeb.UserAuth

  setup %{conn: conn} do
    conn =
      conn
      |> Map.replace!(:secret_key_base, UploadWeb.Endpoint.config(:secret_key_base))
      |> init_test_session(%{})

    %{conn: conn}
  end

  describe "fetch_current_user/2" do
    test "assigns current_user to nil if session is empty", %{conn: conn} do
      conn = UserAuth.fetch_current_user(conn, [])
      refute conn.assigns.current_user
    end

    test "assigns current_user if session has user_id", %{conn: conn} do
      user = AccountsFixtures.user_fixture()

      conn =
        conn
        |> put_session(:user_id, user.id)
        |> UserAuth.fetch_current_user([])

      assert conn.assigns.current_user.id == user.id
    end
  end

  describe "require_authenticated_user/2" do
    test "redirects if user is not authenticated", %{conn: conn} do
      conn = conn |> fetch_flash() |> UserAuth.require_authenticated_user([])
      assert conn.halted
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You must log in to access this page."
    end

    test "does not redirect if user is authenticated", %{conn: conn} do
      user = AccountsFixtures.user_fixture()

      conn =
        conn
        |> assign(:current_user, user)
        |> UserAuth.require_authenticated_user([])

      refute conn.halted
    end
  end

  describe "require_admin_user/2" do
    test "redirects if user is not admin", %{conn: conn} do
      user = AccountsFixtures.user_fixture()

      conn =
        conn
        |> assign(:current_user, user)
        |> fetch_flash()
        |> UserAuth.require_admin_user([])

      assert conn.halted
      assert redirected_to(conn) == ~p"/"

      assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
               "You do not have access to this page."
    end

    test "does not redirect if user is admin", %{conn: conn} do
      admin = AccountsFixtures.admin_fixture()

      conn =
        conn
        |> assign(:current_user, admin)
        |> UserAuth.require_admin_user([])

      refute conn.halted
    end
  end
end
