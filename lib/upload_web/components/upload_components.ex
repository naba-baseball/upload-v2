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

  @doc """
  Renders a deployment status badge.

  ## Examples

      <.deployment_status status="deployed" />
      <.deployment_status status="deploying" />
      <.deployment_status status="failed" error="Connection timeout" />
  """
  attr :status, :string, required: true, doc: "The deployment status"
  attr :last_deployed_at, :any, default: nil, doc: "DateTime of last successful deployment"
  attr :error, :string, default: nil, doc: "Error message for failed deployments"

  def deployment_status(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <span class={[
        "inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-medium",
        status_classes(@status)
      ]}>
        <span class={["w-2 h-2 rounded-full", status_dot_classes(@status)]}></span>
        {status_label(@status)}
      </span>

      <%= if @status == "deployed" && @last_deployed_at do %>
        <span class="text-xs text-gray-500 dark:text-gray-400">
          {format_time(@last_deployed_at)}
        </span>
      <% end %>
    </div>
    """
  end

  defp status_classes("pending"),
    do: "bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200"

  defp status_classes("deploying"),
    do: "bg-blue-100 dark:bg-blue-900/50 text-blue-800 dark:text-blue-200"

  defp status_classes("deployed"),
    do: "bg-green-100 dark:bg-green-900/50 text-green-800 dark:text-green-200"

  defp status_classes("failed"),
    do: "bg-red-100 dark:bg-red-900/50 text-red-800 dark:text-red-200"

  defp status_classes(_), do: "bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200"

  defp status_dot_classes("pending"), do: "bg-gray-400 dark:bg-gray-500"
  defp status_dot_classes("deploying"), do: "bg-blue-500 animate-pulse"
  defp status_dot_classes("deployed"), do: "bg-green-500"
  defp status_dot_classes("failed"), do: "bg-red-500"
  defp status_dot_classes(_), do: "bg-gray-400 dark:bg-gray-500"

  defp status_label("pending"), do: "Pending"
  defp status_label("deploying"), do: "Deploying"
  defp status_label("deployed"), do: "Deployed"
  defp status_label("failed"), do: "Failed"
  defp status_label(status), do: status

  defp format_time(nil), do: ""

  defp format_time(datetime) do
    Calendar.strftime(datetime, "%b %d, %H:%M")
  end

  @doc """
  Renders site URL links based on the routing mode.

  ## Examples

      <.site_url_links site={@site} />
      <.site_url_links site={site} icon="hero-arrow-top-right-on-square" />
      <.site_url_links site={@site} display="full_url" />

  """
  attr :site, :map, required: true
  attr :icon, :string, default: nil, doc: "Optional icon name to display before each link"

  attr :display, :string,
    default: "domain",
    doc: "Display mode: 'domain' for domain/subpath, 'full_url' for complete URL"

  def site_url_links(assigns) do
    ~H"""
    <div class="space-y-1">
      <%= if @site.routing_mode in ["subdomain", "subpath"] do %>
        <.link
          href={Upload.Sites.Site.format_site_url(@site)}
          target="_blank"
          rel="noopener noreferrer"
          class={[
            "text-indigo-600 dark:text-indigo-400 font-mono hover:text-indigo-800 dark:hover:text-indigo-200 hover:underline",
            if(@icon, do: "inline-flex items-center gap-2 text-sm", else: "block")
          ]}
        >
          <%= if @icon do %>
            <.icon name={@icon} class="w-4 h-4" />
          <% end %>
          <%= if @display == "full_url" do %>
            {Upload.Sites.Site.format_site_url(@site)}
          <% else %>
            <%= if @site.routing_mode == "subdomain" do %>
              {Upload.Sites.Site.full_domain(@site)}
            <% else %>
              {Upload.Sites.Site.subpath(@site)}
            <% end %>
          <% end %>
        </.link>
      <% end %>
      <%= if @site.routing_mode == "both" do %>
        <.link
          href={Upload.Sites.Site.format_site_url(@site, :subdomain)}
          target="_blank"
          rel="noopener noreferrer"
          class={[
            "text-indigo-600 dark:text-indigo-400 font-mono hover:text-indigo-800 dark:hover:text-indigo-200 hover:underline",
            if(@icon, do: "inline-flex items-center gap-2 text-sm", else: "block")
          ]}
        >
          <%= if @icon do %>
            <.icon name={@icon} class="w-4 h-4" />
          <% end %>
          <%= if @display == "full_url" do %>
            {Upload.Sites.Site.format_site_url(@site, :subdomain)}
          <% else %>
            {Upload.Sites.Site.full_domain(@site)}
          <% end %>
        </.link>
        <.link
          href={Upload.Sites.Site.format_site_url(@site, :subpath)}
          target="_blank"
          rel="noopener noreferrer"
          class={[
            "text-indigo-600 dark:text-indigo-400 font-mono hover:text-indigo-800 dark:hover:text-indigo-200 hover:underline",
            if(@icon, do: "inline-flex items-center gap-2 text-sm", else: "block")
          ]}
        >
          <%= if @icon do %>
            <.icon name={@icon} class="w-4 h-4" />
          <% end %>
          <%= if @display == "full_url" do %>
            {Upload.Sites.Site.format_site_url(@site, :subpath)}
          <% else %>
            {Upload.Sites.Site.subpath(@site)}
          <% end %>
        </.link>
      <% end %>
    </div>
    """
  end
end
