defmodule UploadWeb.UserAuth do
  import Plug.Conn
  import Phoenix.Controller

  alias Upload.Accounts

  def fetch_current_user(conn, _opts) do
    user_id = get_session(conn, :user_id)
    user = user_id && Accounts.get_user(user_id)
    assign(conn, :current_user, user)
  end

  def require_authenticated_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> put_flash(:error, "You must log in to access this page.")
      |> redirect(to: "/")
      |> halt()
    end
  end

  def require_admin_user(conn, _opts) do
    user = conn.assigns[:current_user]
    if user && user.role == "admin" do
      conn
    else
      conn
      |> put_flash(:error, "You do not have access to this page.")
      |> redirect(to: "/")
      |> halt()
    end
  end
end
