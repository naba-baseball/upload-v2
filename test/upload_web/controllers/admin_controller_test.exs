defmodule UploadWeb.AdminControllerTest do
  use UploadWeb.ConnCase

  import Upload.AccountsFixtures

  describe "GET /admin" do
    test "redirects to home if not logged in", %{conn: conn} do
      conn = get(conn, ~p"/admin")
      assert redirected_to(conn) == ~p"/"
    end

    test "redirects to home if logged in as regular user", %{conn: conn} do
      user = user_fixture()
      conn = 
        conn
        |> init_test_session(%{user_id: user.id})
        |> get(~p"/admin")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You do not have access"
    end

    test "renders admin portal if logged in as admin", %{conn: conn} do
      admin = admin_fixture()
      conn = 
        conn
        |> init_test_session(%{user_id: admin.id})
        |> get(~p"/admin")

      assert html_response(conn, 200) =~ "Admin Portal"
      assert html_response(conn, 200) =~ admin.name
    end
  end
end
