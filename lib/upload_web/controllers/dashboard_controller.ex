defmodule UploadWeb.DashboardController do
  use UploadWeb, :controller

  def index(conn, _params) do
    render(conn, :index)
  end
end
