defmodule UploadWeb.AuthControllerTest do
  use UploadWeb.ConnCase

  alias Upload.Repo
  alias Upload.Accounts.User

  @ueberauth_auth %{
    provider: :discord,
    uid: "12345",
    info: %{
      email: "test@example.com",
      name: "Test User",
      nickname: "testuser",
      image: "http://example.com/avatar.jpg"
    }
  }

  describe "GET /auth/:provider/callback" do
    test "creates user and redirects to dashboard on success", %{conn: conn} do
      conn =
        conn
        |> assign(:ueberauth_auth, @ueberauth_auth)
        |> get(~p"/auth/discord/callback")

      assert redirected_to(conn) == ~p"/dashboard"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Successfully authenticated"

      user = Repo.get_by(User, email: "test@example.com")
      assert user
      assert get_session(conn, :user_id) == user.id
    end

    test "redirects to admin if user is admin", %{conn: conn} do
      # Create admin first
      {:ok, admin} =
        Upload.Accounts.find_or_create_user(%{
          @ueberauth_auth
          | uid: "admin_uid",
            info: %{@ueberauth_auth.info | email: "admin@example.com"}
        })

      # Manually set role to admin
      Ecto.Changeset.change(admin, role: "admin") |> Repo.update!()

      admin_auth = %{
        @ueberauth_auth
        | uid: "admin_uid",
          info: %{@ueberauth_auth.info | email: "admin@example.com"}
      }

      conn =
        conn
        |> assign(:ueberauth_auth, admin_auth)
        |> get(~p"/auth/discord/callback")

      assert redirected_to(conn) == ~p"/admin/sites"
      assert get_session(conn, :user_id) == admin.id
    end

    test "handles failure", %{conn: conn} do
      # No ueberauth_auth assign implies failure/bad request usually caught by Ueberauth plug or fallthrough
      conn = get(conn, ~p"/auth/discord/callback")

      # Since we defined a catch-all callback/2 in AuthController, it should handle cases without auth struct
      # However, Ueberauth plug might intercept first.
      # In our controller: def callback(conn, _params) matches if the first one fails matching.

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Authentication failed"
    end
  end

  describe "GET /auth/signout" do
    test "drops session and redirects home", %{conn: conn} do
      conn =
        conn
        |> init_test_session(%{user_id: 1})
        |> get(~p"/auth/signout")

      assert redirected_to(conn) == ~p"/"
      assert conn.private.plug_session_info == :drop
    end
  end

  describe "session persistence" do
    test "session cookie has max_age set to persist across browser sessions", %{conn: conn} do
      conn =
        conn
        |> assign(:ueberauth_auth, @ueberauth_auth)
        |> get(~p"/auth/discord/callback")

      # Get the session cookie
      session_cookie = conn.resp_cookies["_upload_key"]

      # Verify the cookie exists
      assert session_cookie, "Session cookie should be set"

      # Verify max_age is set to 60 days (in seconds)
      expected_max_age = 60 * 24 * 60 * 60
      assert session_cookie.max_age == expected_max_age,
             "Session cookie should have max_age of #{expected_max_age} seconds (60 days), got #{session_cookie.max_age}"
    end
  end
end
