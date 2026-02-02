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
          <p class="text-base-content mb-8 max-w-md mx-auto">
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

        <%= if @single_site do %>
          <%!-- Single site: show streamlined layout --%>
          <div class="space-y-8">
            <div class="vintage-card bg-gradient-to-br from-base-100 to-base-200 overflow-hidden">
              <div class="p-8 pb-0">
                <div class="flex items-center justify-between mb-6">
                  <div>
                    <h2 class="font-heading text-3xl font-bold text-primary mb-2">
                      {@single_site.name}
                    </h2>
                    <div class="flex items-center gap-4 text-sm text-secondary">
                      <.deployment_status
                        status={@single_site.deployment_status}
                        last_deployed_at={@single_site.last_deployed_at}
                        error={@single_site.last_deployment_error}
                      />
                    </div>
                  </div>
                  <div class="text-right">
                    <.site_url_links site={@single_site} icon="hero-arrow-top-right-on-square" />
                  </div>
                </div>
              </div>

              <div class="vintage-ornament mx-8">
                <div class="vintage-ornament-diamond"></div>
              </div>

              <div class="p-8 pt-4">
                <div class="flex items-center justify-between mb-6">
                  <h3 class="font-heading text-xl text-primary">Quick Actions</h3>
                </div>
                <div class="flex flex-wrap gap-4">
                  <.link
                    navigate={~p"/sites/#{@single_site.id}/webhooks"}
                    class="vintage-btn vintage-btn-secondary inline-flex items-center gap-2"
                  >
                    <.icon name="hero-bell" class="w-4 h-4" /> Manage Webhooks
                  </.link>
                </div>
              </div>
            </div>

            <div class="vintage-card card-hover baseball-stitches corner-decoration bg-gradient-to-br from-base-100 to-base-200">
              <div class="p-8">
                <div class="text-center mb-6">
                  <div class="inline-flex items-center justify-center w-16 h-16 bg-primary/10 rounded-full mb-4">
                    <.icon name="hero-cloud-arrow-up" class="w-8 h-8 text-primary" />
                  </div>
                  <h3 class="font-heading text-2xl font-bold text-primary mb-2">
                    Upload Site Archive
                  </h3>
                  <p class="text-secondary">
                    Upload a .tar.gz file containing the site assets.
                  </p>
                </div>

                <.upload_form upload={@uploads.site_archive} />
              </div>
            </div>
          </div>
        <% else %>
          <%!-- Multiple sites: show improved grid layout --%>
          <div class="mb-8">
            <div class="vintage-ornament mb-6">
              <div class="vintage-ornament-diamond"></div>
            </div>
            <h2 class="font-heading text-3xl font-bold text-center mb-8">Your Sites</h2>
          </div>

          <%= if @sites != [] do %>
            <div class="grid gap-6 md:grid-cols-2 lg:grid-cols-3">
              <.card
                :for={site <- @sites}
                variant="default"
                hover
                class="group relative overflow-hidden"
              >
                <div class="absolute top-4 right-4 opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                  <.deployment_status
                    status={site.deployment_status}
                    last_deployed_at={site.last_deployed_at}
                  />
                </div>

                <div class="mb-6">
                  <div class="flex items-start justify-between mb-4">
                    <div class="flex-1">
                      <h3 class="font-heading text-xl font-bold mb-2 group-hover:text-accent transition-colors">
                        {site.name}
                      </h3>
                      <div class="h-1 w-16 bg-accent rounded-full"></div>
                    </div>
                  </div>

                  <div class="space-y-3">
                    <.site_url_links site={site} icon="hero-globe-alt" />
                  </div>
                </div>

                <div class="border-t border-primary/20 pt-4">
                  <.link
                    navigate={~p"/sites/#{site.id}/upload"}
                    class="vintage-btn vintage-btn-primary w-full justify-center text-sm"
                  >
                    <.icon name="hero-arrow-up-tray" class="w-4 h-4" /> Upload
                  </.link>
                  <.link
                    navigate={~p"/sites/#{site.id}/webhooks"}
                    class="vintage-btn vintage-btn-secondary w-full justify-center text-sm"
                  >
                    <.icon name="hero-cog-6-tooth" class="w-4 h-4" /> Settings
                  </.link>
                </div>
              </.card>
            </div>
          <% else %>
            <div class="vintage-card bg-gradient-to-br from-base-100 to-base-200 text-center py-12">
              <div class="inline-flex items-center justify-center w-20 h-20 bg-primary/10 rounded-full mb-6">
                <.icon name="hero-inbox" class="w-10 h-10 text-primary" />
              </div>
              <h3 class="font-heading text-2xl font-bold text-primary mb-4">No Sites Yet</h3>
              <p class="text-secondary max-w-md mx-auto">
                You haven't been assigned to any sites yet. Please contact an administrator to get access.
              </p>
            </div>
          <% end %>
        <% end %>

        <div class="mt-12 vintage-card bg-gradient-to-br from-base-100 to-base-200">
          <div class="p-8">
            <div class="flex items-center gap-4 mb-6">
              <div class="w-12 h-12 bg-primary/10 rounded-full flex items-center justify-center">
                <.icon name="hero-user" class="w-6 h-6" />
              </div>
              <h2 class="font-heading text-2xl font-bold">Account Information</h2>
            </div>
            <.user_profile user={@current_user} />
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
