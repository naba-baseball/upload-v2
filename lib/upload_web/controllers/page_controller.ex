defmodule UploadWeb.PageController do
  use UploadWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
