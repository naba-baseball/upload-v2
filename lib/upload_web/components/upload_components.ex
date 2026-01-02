defmodule UploadWeb.UploadComponents do
  @moduledoc """
  Reusable upload form components.
  """
  use Phoenix.Component
  import UploadWeb.CoreComponents

  @doc """
  Renders the site archive upload form.

  ## Examples

      <.upload_form upload={@uploads.site_archive} />
  """
  attr :upload, :map, required: true, doc: "The upload configuration from allow_upload/3"

  def upload_form(assigns) do
    ~H"""
    <form
      id="upload-form"
      phx-submit="save"
      phx-change="validate"
      phx-drop-target={@upload.ref}
    >
      <div class="mb-4">
        <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
          Site Archive (.tar.gz)
        </label>
        <.live_file_input
          upload={@upload}
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
        <%= for entry <- @upload.entries do %>
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

            <%= for err <- upload_errors(@upload, entry) do %>
              <p class="text-red-600 dark:text-red-400 text-sm mt-1">
                {error_to_string(err)}
              </p>
            <% end %>
          </div>
        <% end %>

        <%= for err <- upload_errors(@upload) do %>
          <p class="text-red-600 dark:text-red-400 mb-2">
            {error_to_string(err)}
          </p>
        <% end %>
      </section>

      <button
        type="submit"
        disabled={@upload.entries == []}
        phx-disable-with="Uploading..."
        class="inline-flex items-center gap-2 px-4 py-2 bg-indigo-600 hover:bg-indigo-700 text-white font-semibold rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
      >
        <.icon name="hero-arrow-up-tray" class="w-5 h-5" /> Upload Archive
      </button>
    </form>
    """
  end

  defp error_to_string(:too_large), do: "File is too large (max 500MB)"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "Only .tar.gz files are accepted"
end
