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

      assert redirected_to(conn) == ~p"/admin"
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
end
