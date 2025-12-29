defmodule UploadWeb.AdminLive do
  use UploadWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> allow_upload(:site_archive,
       accept: ~w(.gz),
       max_entries: 1,
       max_file_size: 524_288_000
     ), layout: {UploadWeb.Layouts, :app}}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    consume_uploaded_entries(socket, :site_archive, fn %{path: path}, entry ->
      dest = Path.join(System.tmp_dir!(), "site_archive_#{entry.uuid}.tar.gz")
      File.cp!(path, dest)
      {:ok, dest}
    end)

    {:noreply,
     socket
     |> put_flash(:info, "File uploaded successfully")
     |> push_navigate(to: ~p"/admin")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-2xl py-8">
      <h1 class="text-4xl font-bold mb-4">Admin Portal</h1>
      <p class="mb-8">Upload a .tar.gz file containing the site assets.</p>

      <form
        id="upload-form"
        phx-submit="save"
        phx-change="validate"
        phx-drop-target={@uploads.site_archive.ref}
      >
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">
            Site Archive (.tar.gz)
          </label>
          <.live_file_input
            upload={@uploads.site_archive}
            class="block w-full text-sm text-gray-500
            file:mr-4 file:py-2 file:px-4
            file:rounded-full file:border-0
            file:text-sm file:font-semibold
            file:bg-indigo-50 file:text-indigo-700
            hover:file:bg-indigo-100
          "
          />
        </div>

        <section class="mb-4">
          <%= for entry <- @uploads.site_archive.entries do %>
            <article class="upload-entry border rounded p-4 mb-2 bg-gray-50">
              <figure class="flex items-center justify-between mb-2">
                <span class="font-mono text-sm">{entry.client_name}</span>
                <span class="text-sm text-gray-500">{entry.progress}%</span>
              </figure>

              <div class="w-full bg-gray-200 rounded-full h-2.5">
                <div
                  class="bg-indigo-600 h-2.5 rounded-full transition-all duration-300"
                  style={"width: #{entry.progress}%"}
                >
                </div>
              </div>

              <%= for err <- upload_errors(@uploads.site_archive, entry) do %>
                <p class="alert alert-danger text-red-600 text-sm mt-1">{error_to_string(err)}</p>
              <% end %>
            </article>
          <% end %>

          <%= for err <- upload_errors(@uploads.site_archive) do %>
            <p class="alert alert-danger text-red-600 mb-2">{error_to_string(err)}</p>
          <% end %>
        </section>

        <button
          type="submit"
          phx-disable-with="Uploading..."
          class="bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700 disabled:opacity-50"
        >
          Upload Archive
        </button>
      </form>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
