defmodule UploadWeb.DashboardControllerTest do
  use UploadWeb.ConnCase

  import Upload.AccountsFixtures

  describe "GET /dashboard" do
    test "redirects to home if not logged in", %{conn: conn} do
      conn = get(conn, ~p"/dashboard")
      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "You must log in"
    end

    test "renders dashboard if logged in", %{conn: conn} do
      user = user_fixture()
      conn = 
        conn
        |> init_test_session(%{user_id: user.id})
        |> get(~p"/dashboard")

      assert html_response(conn, 200) =~ "User Dashboard"
      assert html_response(conn, 200) =~ user.name
    end
  end
end
