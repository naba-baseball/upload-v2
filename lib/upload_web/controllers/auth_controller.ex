defmodule UploadWeb.AuthController do
  use UploadWeb, :controller
  require Logger
  plug Ueberauth

  alias Upload.Accounts

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case Accounts.find_or_create_user(auth) do
      {:ok, user} ->
        Logger.info(
          message: "Authentication successful",
          event: "auth.callback.success",
          user_id: user.id,
          provider: auth.provider,
          user_role: user.role
        )

        path = if user.role == "admin", do: ~p"/admin", else: ~p"/dashboard"

        conn
        |> configure_session(renew: true)
        |> put_session(:user_id, user.id)
        |> put_flash(:info, "Successfully authenticated.")
        |> redirect(to: path)

      {:error, reason} ->
        Logger.error(
          message: "Authentication failed: could not find or create user",
          event: "auth.callback.error",
          provider: auth.provider,
          reason: inspect(reason)
        )

        conn
        |> put_flash(:error, "Error signing in: #{inspect(reason)}")
        |> redirect(to: ~p"/")
    end
  end

  def callback(conn, _params) do
    Logger.error(
      message: "Authentication failed: Ueberauth failure",
      event: "auth.callback.failure",
      provider: conn.params["provider"],
      params: conn.params
    )

    conn
    |> put_flash(:error, "Authentication failed")
    |> redirect(to: ~p"/")
  end

  def signout(conn, _params) do
    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/")
  end
end
