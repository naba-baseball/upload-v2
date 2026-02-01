defmodule UploadWeb.SiteUploadLive do
  use UploadWeb, :live_view

  import UploadWeb.UploadComponents

  alias Upload.FileValidator
  alias Upload.Sites
  alias Upload.SiteUploader
  alias Upload.Workers.DeploymentWorker

  require Logger

  @impl true
  def mount(%{"site_id" => site_id}, _session, socket) do
    user_id = socket.assigns.current_user.id

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

        # Queue deployment job
        %{site_id: site.id, tarball_path: dest}
        |> DeploymentWorker.new()
        |> Oban.insert()

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
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-2xl py-8 px-4">
        <div class="mb-6">
          <.back_link navigate={~p"/dashboard"}>Back to Dashboard</.back_link>
        </div>

        <.card variant="white">
          <div class="mb-6">
            <div class="flex items-center justify-between mb-1">
              <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">
                Upload to {@site.name}
              </h1>
              <.deployment_status
                status={@site.deployment_status}
                last_deployed_at={@site.last_deployed_at}
                error={@site.last_deployment_error}
              />
            </div>
            <div class="mt-1 text-sm text-gray-600 dark:text-gray-400">
              <.site_url_links site={@site} icon="hero-globe-alt" />
            </div>
          </div>

          <p class="mb-6 text-gray-600 dark:text-gray-400">
            Upload a .tar.gz file containing the site assets.
          </p>

          <.upload_form upload={@uploads.site_archive} />
        </.card>
      </div>
    </Layouts.app>
    """
  end
end
