defmodule UploadWeb.SiteUploadLive do
  use UploadWeb, :live_view

  import UploadWeb.UploadComponents

  alias Upload.DeploymentRunner
  alias Upload.FileValidator
  alias Upload.Sites
  alias Upload.SiteUploader

  require Logger

  @impl true
  def mount(%{"site_id" => site_id}, _session, socket) do
    case socket.assigns.current_user do
      nil ->
        {:ok, assign(socket, :requires_auth, true)}

      current_user ->
        user_id = current_user.id

        if Sites.user_assigned_to_site?(user_id, site_id) do
          site = Sites.get_site!(site_id)

          if connected?(socket) do
            Phoenix.PubSub.subscribe(Upload.PubSub, "site:#{site.id}")
          end

          {:ok,
           socket
           |> assign(:page_title, "Upload to #{site.name}")
           |> assign(:site, site)
           |> allow_upload(:site_archive,
             accept: ~w(.gz),
             max_entries: 1,
             max_file_size: 524_288_000
           )}
        else
          {:ok,
           socket
           |> put_flash(:error, "You don't have access to this site")
           |> push_navigate(to: ~p"/dashboard")}
        end
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    site = socket.assigns.site
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
      |> assign(:site, site)
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
    <%= if Map.get(assigns, :requires_auth) do %>
      <Layouts.app flash={@flash} current_user={@current_user}>
        <div class="mx-auto max-w-4xl py-8 px-4 text-center">
          <div class="text-gray-400 dark:text-gray-600 mb-6">
            <.icon name="hero-lock-closed" class="w-16 h-16 mx-auto" />
          </div>
          <h1 class="text-3xl font-bold mb-4 text-gray-900 dark:text-gray-100">
            Sign In Required
          </h1>
          <p class="text-gray-600 dark:text-gray-400 mb-8 max-w-md mx-auto">
            Please sign in with Discord to upload site archives.
          </p>
          <.link
            href={~p"/auth/discord"}
            class="vintage-btn vintage-btn-primary inline-flex items-center gap-2"
          >
            <.icon name="hero-arrow-right-on-rectangle" class="w-5 h-5" /> Sign in with Discord
          </.link>
        </div>
      </Layouts.app>
    <% else %>
      <Layouts.app flash={@flash} current_user={@current_user}>
        <div class="mx-auto max-w-4xl">
          <.back_link navigate={~p"/dashboard"} class="mb-6">Back to Dashboard</.back_link>

          <div class="vintage-card bg-gradient-to-br from-base-100 to-base-200">
            <div class="p-8 pb-0">
              <div class="text-center mb-6">
                <div class="inline-flex items-center justify-center w-16 h-16 bg-primary/10 rounded-full mb-4">
                  <.icon name="hero-cloud-arrow-up" class="w-8 h-8" />
                </div>
                <h1 class="font-heading text-3xl font-bold mb-2">
                  Upload to {@site.name}
                </h1>
                <div class="flex items-center justify-center gap-4 text-sm text-secondary">
                  <.deployment_status
                    status={@site.deployment_status}
                    last_deployed_at={@site.last_deployed_at}
                    error={@site.last_deployment_error}
                  />
                  <.site_url_links site={@site} icon="hero-globe-alt" />
                </div>
              </div>
            </div>

            <div class="vintage-ornament mx-8">
              <div class="vintage-ornament-diamond"></div>
            </div>

            <div class="p-8 pt-4">
              <p class="text-center mb-6 text-secondary">
                Upload a .tar.gz file containing the site assets.
              </p>
              <div class="max-w-md mx-auto">
                <.upload_form upload={@uploads.site_archive} />
              </div>
            </div>
          </div>
        </div>
      </Layouts.app>
    <% end %>
    """
  end
end
