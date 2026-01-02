defmodule UploadWeb.SiteUploadLive do
  use UploadWeb, :live_view

  import UploadWeb.UploadComponents

  alias Upload.FileValidator
  alias Upload.Sites
  alias Upload.SiteUploader

  require Logger

  @impl true
  def mount(%{"site_id" => site_id}, _session, socket) do
    user_id = socket.assigns.current_user.id

    if Sites.user_assigned_to_site?(user_id, site_id) do
      site = Sites.get_site!(site_id)

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

        {:noreply,
         socket
         |> put_flash(:info, "File uploaded successfully!")
         |> push_navigate(to: ~p"/sites/#{site.id}/upload")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-2xl py-8 px-4">
        <div class="mb-6">
          <.back_link navigate={~p"/dashboard"}>Back to Dashboard</.back_link>
        </div>

        <.card variant="white">
          <div class="mb-6">
            <h1 class="text-2xl font-bold text-gray-900 dark:text-gray-100">
              Upload to {@site.name}
            </h1>
            <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
              <.icon name="hero-globe-alt" class="w-4 h-4 inline" />
              {Upload.Sites.Site.full_domain(@site)}
            </p>
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
