defmodule UploadWeb.AdminLiveTest do
  use UploadWeb.ConnCase

  import Phoenix.LiveViewTest
  import Upload.AccountsFixtures

  describe "Admin Dashboard" do
    test "redirects to home if not logged in", %{conn: conn} do
      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin")
    end

    test "redirects to home if logged in as regular user", %{conn: conn} do
      user = user_fixture()
      conn = init_test_session(conn, %{user_id: user.id})

      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/admin")
    end

    test "renders upload form if logged in as admin", %{conn: conn} do
      admin = admin_fixture()
      conn = init_test_session(conn, %{user_id: admin.id})

      {:ok, _view, html} = live(conn, ~p"/admin")
      assert html =~ "Admin Portal"
      assert html =~ "Upload a .tar.gz file"
    end

    test "rejects file that is too large", %{conn: conn} do
      admin = admin_fixture()
      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, view, _html} = live(conn, ~p"/admin")

      # 500MB + 1 byte = 524,288,001 bytes
      content = :crypto.strong_rand_bytes(524_288_001)
      
      upload =
        file_input(view, "#upload-form", :site_archive, [
          %{
            name: "huge.tar.gz",
            content: content,
            type: "application/gzip"
          }
        ])

      result = render_upload(upload, "huge.tar.gz")
      assert {:error, [[_ref, :too_large]]} = result
    end

    test "uploads file successfully", %{conn: conn} do
      admin = admin_fixture()
      conn = init_test_session(conn, %{user_id: admin.id})
      {:ok, view, _html} = live(conn, ~p"/admin")

      upload =
        file_input(view, "#upload-form", :site_archive, [
          %{
            name: "test.tar.gz",
            content: "fake content",
            type: "application/gzip"
          }
        ])

      assert render_upload(upload, "test.tar.gz") =~ "100%"

      {:ok, _view, html} =
        view
        |> form("#upload-form", %{})
        |> render_submit()
        |> follow_redirect(conn, ~p"/admin")

      assert html =~ "File uploaded successfully"
    end
  end
end
