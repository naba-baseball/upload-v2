defmodule UploadWeb.SiteUploadLive do
  use UploadWeb, :live_view

  alias Upload.Sites

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

    [dest] =
      consume_uploaded_entries(socket, :site_archive, fn %{path: path}, entry ->
        dest = Path.join(System.tmp_dir!(), "#{site.subdomain}_#{entry.uuid}.tar.gz")
        File.cp!(path, dest)
        {:ok, dest}
      end)

    Logger.info(
      event: "site.upload.created",
      site_id: site.id,
      subdomain: site.subdomain,
      user_id: socket.assigns.current_user.id,
      path: dest
    )

    {:noreply,
     socket
     |> put_flash(:info, "File uploaded successfully!")
     |> push_navigate(to: ~p"/sites/#{site.id}/upload")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-2xl py-8 px-4">
        <div class="mb-6">
          <.link
            navigate={~p"/dashboard"}
            class="inline-flex items-center gap-1 text-sm text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Dashboard
          </.link>
        </div>

        <div class="bg-white dark:bg-gray-800 rounded-lg shadow dark:shadow-gray-900/50 p-6 border border-transparent dark:border-gray-700">
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

          <form
            id="upload-form"
            phx-submit="save"
            phx-change="validate"
            phx-drop-target={@uploads.site_archive.ref}
          >
            <div class="mb-4">
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                Site Archive (.tar.gz)
              </label>
              <.live_file_input
                upload={@uploads.site_archive}
                required
                class="block w-full text-sm text-gray-500 dark:text-gray-400
                file:mr-4 file:py-2 file:px-4
                file:rounded-full file:border-0
                file:text-sm file:font-semibold
                file:bg-indigo-50 dark:file:bg-indigo-900/50 file:text-indigo-700 dark:file:text-indigo-300
                hover:file:bg-indigo-100 dark:hover:file:bg-indigo-900"
              />
            </div>

            <section class="mb-4">
              <%= for entry <- @uploads.site_archive.entries do %>
                <div class="bg-gray-50 dark:bg-gray-900/50 border border-gray-200 dark:border-gray-700 rounded-lg p-4 mb-2">
                  <figure class="flex items-center justify-between mb-2">
                    <span class="font-mono text-sm text-gray-900 dark:text-gray-100">
                      {entry.client_name}
                    </span>
                    <span class="text-sm text-gray-500 dark:text-gray-400">{entry.progress}%</span>
                  </figure>

                  <div class="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2.5">
                    <div
                      class="bg-indigo-600 dark:bg-indigo-500 h-2.5 rounded-full transition-all duration-300"
                      style={"width: #{entry.progress}%"}
                    >
                    </div>
                  </div>

                  <%= for err <- upload_errors(@uploads.site_archive, entry) do %>
                    <p class="text-red-600 dark:text-red-400 text-sm mt-1">
                      {error_to_string(err)}
                    </p>
                  <% end %>
                </div>
              <% end %>

              <%= for err <- upload_errors(@uploads.site_archive) do %>
                <p class="text-red-600 dark:text-red-400 mb-2">
                  {error_to_string(err)}
                </p>
              <% end %>
            </section>

            <button
              type="submit"
              disabled={@uploads.site_archive.entries == []}
              phx-disable-with="Uploading..."
              class="inline-flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <.icon name="hero-arrow-up-tray" class="w-5 h-5" /> Upload Archive
            </button>
          </form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp error_to_string(:too_large), do: "File is too large (max 500MB)"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "Only .tar.gz files are accepted"
end
