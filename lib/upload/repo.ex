defmodule Upload.Repo do
  use Ecto.Repo,
    otp_app: :upload,
    adapter: Ecto.Adapters.SQLite3
end
