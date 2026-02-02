defmodule UploadWeb.DashboardLive do
  use UploadWeb, :live_view

  import UploadWeb.UploadComponents

  alias Upload.Accounts
  alias Upload.DeploymentRunner
  alias Upload.FileValidator
  alias Upload.SiteUploader

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    case socket.assigns.current_user do
      nil ->
        {:ok, assign(socket, :page_title, "Dashboard"), layout: {UploadWeb.Layouts, :app}}

      current_user ->
        user = Accounts.get_user_with_sites!(current_user.id)

        socket =
          socket
          |> assign(:page_title, "Dashboard")
          |> assign(:sites, user.sites)

        # If user has exactly 1 site, enable upload directly on dashboard
        socket =
          case user.sites do
            [site] ->
              if connected?(socket) do
                Phoenix.PubSub.subscribe(Upload.PubSub, "site:#{site.id}")
              end

              socket
              |> assign(:single_site, site)
              |> allow_upload(:site_archive,
                accept: ~w(.gz),
                max_entries: 1,
                max_file_size: 524_288_000
              )

            _ ->
              assign(socket, :single_site, nil)
          end

        {:ok, socket, layout: {UploadWeb.Layouts, :app}}
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    site = socket.assigns.single_site
    user_id = socket.assigns.current_user.id

    results =
      consume_uploaded_entries(socket, :site_archive, fn %{path: path}, entry ->
        SiteUploader.process_upload(path, site, entry.uuid)
      end)

    case results do
      [{:error, reason}] ->
        Logger.warning(
          event: "site.upload.rejected",
          site_id: site.id,
          subdomain: site.subdomain,
          user_id: user_id,
          reason: reason
        )

        {:noreply, put_flash(socket, :error, FileValidator.error_message(reason))}

      [dest] ->
        Logger.info(
          event: "site.upload.created",
          site_id: site.id,
          subdomain: site.subdomain,
          user_id: user_id,
          path: dest
        )

        # Start deployment task
        DeploymentRunner.start_deployment(site.id, dest)

        {:noreply, put_flash(socket, :info, "Upload received! Deployment in progress...")}
    end
  end

  @impl true
  def handle_info({:deployment_updated, site}, socket) do
    socket =
      socket
      |> assign(:single_site, site)
      |> update(:sites, fn sites ->
        Enum.map(sites, fn s -> if s.id == site.id, do: site, else: s end)
      end)
      |> maybe_flash_deployment_status(site)

    {:noreply, socket}
  end

  defp maybe_flash_deployment_status(socket, %{deployment_status: "deployed"}) do
    put_flash(socket, :info, "Deployment successful!")
  end

  defp maybe_flash_deployment_status(socket, %{deployment_status: "failed"} = site) do
    put_flash(socket, :error, site.last_deployment_error)
  end

  defp maybe_flash_deployment_status(socket, _site), do: socket

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl py-8 px-4">
      <%= if is_nil(@current_user) do %>
        <div class="text-center py-16">
          <div class="text-gray-400 dark:text-gray-600 mb-6">
            <.icon name="hero-lock-closed" class="w-16 h-16 mx-auto" />
          </div>
          <h1 class="text-3xl font-bold mb-4 text-gray-900 dark:text-gray-100">
            Sign In Required
          </h1>
          <p class="text-gray-600 dark:text-gray-400 mb-8 max-w-md mx-auto">
            Please sign in with Discord to access your dashboard and manage your sites.
          </p>
          <.link
            href={~p"/auth/discord"}
            class="inline-flex items-center gap-2 rounded-lg bg-indigo-600 px-6 py-3 text-white font-semibold hover:bg-indigo-700 transition-colors"
          >
            <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5" /> Sign in with Discord
          </.link>
        </div>
      <% else %>
        <div class="mb-8">
          <h1 class="text-4xl font-bold mb-2 text-gray-900 dark:text-gray-100">
            Welcome, {@current_user.name}!
          </h1>
          <p class="text-gray-600 dark:text-gray-400">Your personal dashboard</p>
        </div>

        <%= if @current_user.role == "admin" do %>
          <div class="mb-6 bg-indigo-600 dark:bg-indigo-700 text-white rounded-lg p-4 flex justify-between items-center">
            <div>
              <h3 class="font-semibold">Admin Access</h3>
              <p class="text-sm text-indigo-100 dark:text-indigo-200">
                Manage sites, users, and uploads
              </p>
            </div>
            <.button navigate={~p"/admin/sites"}>
              Go to Admin Panel
            </.button>
          </div>
        <% end %>

        <.card variant="white">
          <%= if @single_site do %>
            <%!-- Single site: show upload form inline --%>
            <div class="mb-6">
              <div class="flex items-center justify-between mb-2">
                <h2 class="text-2xl font-semibold text-gray-900 dark:text-gray-100">
                  {@single_site.name}
                </h2>
                <.deployment_status
                  status={@single_site.deployment_status}
                  last_deployed_at={@single_site.last_deployed_at}
                  error={@single_site.last_deployment_error}
                />
              </div>
              <div class="space-y-1">
                <.site_url_links site={@single_site} icon="hero-arrow-top-right-on-square" />
                <.link
                  navigate={~p"/sites/#{@single_site.id}/webhooks"}
                  class="inline-flex items-center gap-2 text-sm font-medium text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300 transition-colors"
                >
                  <.icon name="hero-bell" class="w-4 h-4" /> Manage Webhooks
                </.link>
              </div>
            </div>

            <div class="border-t border-gray-200 dark:border-gray-700 pt-6">
              <h3 class="text-lg font-semibold mb-4 text-gray-900 dark:text-gray-100">
                Upload Site Archive
              </h3>
              <p class="mb-6 text-gray-600 dark:text-gray-400">
                Upload a .tar.gz file containing the site assets.
              </p>

              <.upload_form upload={@uploads.site_archive} />
            </div>
          <% else %>
            <%!-- Multiple sites or no sites: show cards --%>
            <h2 class="text-2xl font-semibold mb-4 text-gray-900 dark:text-gray-100">Your Sites</h2>

            <%= if @sites != [] do %>
              <div class="grid gap-4 sm:grid-cols-2">
                <.card :for={site <- @sites} variant="indigo" hover class="p-6">
                  <div class="flex items-center justify-between mb-2">
                    <h3 class="text-lg font-semibold text-gray-900 dark:text-gray-100">
                      {site.name}
                    </h3>
                    <.deployment_status
                      status={site.deployment_status}
                      last_deployed_at={site.last_deployed_at}
                    />
                  </div>
                  <div class="flex flex-col gap-2">
                    <.site_url_links site={site} icon="hero-arrow-top-right-on-square" />
                    <.link
                      navigate={~p"/sites/#{site.id}/upload"}
                      class="inline-flex items-center gap-2 text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors"
                    >
                      <.icon name="hero-arrow-up-tray" class="w-4 h-4" /> Upload
                    </.link>
                    <.link
                      navigate={~p"/sites/#{site.id}/webhooks"}
                      class="inline-flex items-center gap-2 text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors"
                    >
                      <.icon name="hero-bell" class="w-4 h-4" /> Webhooks
                    </.link>
                  </div>
                </.card>
              </div>
            <% else %>
              <.empty_state icon="hero-inbox">
                You haven't been assigned to any sites yet. Please contact an administrator to get access.
              </.empty_state>
            <% end %>
          <% end %>
        </.card>

        <.card variant="white" class="mt-8">
          <h2 class="text-2xl font-semibold mb-4 text-gray-900 dark:text-gray-100">
            Account Information
          </h2>
          <.user_profile user={@current_user} />
        </.card>
      <% end %>
    </div>
    """
  end
end
