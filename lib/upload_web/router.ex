defmodule UploadWeb.Router do
  use UploadWeb, :router
  import Oban.Web.Router
  import UploadWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {UploadWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/auth", UploadWeb do
    pipe_through :browser

    get "/signout", AuthController, :signout
    get "/:provider", AuthController, :request
    get "/:provider/callback", AuthController, :callback
  end

  scope "/", UploadWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  scope "/", UploadWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :authenticated, on_mount: [{UploadWeb.UserAuth, :mount_current_user}] do
      live "/dashboard", DashboardLive
      live "/sites/:site_id/upload", SiteUploadLive
    end
  end

  scope "/admin", UploadWeb.Admin do
    pipe_through [:browser, :require_authenticated_user, :require_admin_user]

    live_session :admin, on_mount: [{UploadWeb.UserAuth, :mount_current_user}] do
      live "/sites", SitesLive
      live "/users", UsersLive
    end
  end

  # Other scopes may use custom stacks.
  # scope "/api", UploadWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:upload, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: UploadWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/" do
      pipe_through :browser

      oban_dashboard("/oban")
    end
  end
end
