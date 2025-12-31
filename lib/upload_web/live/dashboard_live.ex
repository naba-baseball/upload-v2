defmodule UploadWeb.DashboardLive do
  use UploadWeb, :live_view

  import UploadWeb.UploadComponents

  alias Upload.Accounts

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    user = Accounts.get_user_with_sites!(socket.assigns.current_user.id)

    socket =
      socket
      |> assign(:page_title, "Dashboard")
      |> assign(:sites, user.sites)

    # If user has exactly 1 site, enable upload directly on dashboard
    socket =
      case user.sites do
        [site] ->
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

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", _params, socket) do
    site = socket.assigns.single_site

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
     |> push_navigate(to: ~p"/dashboard")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl py-8 px-4">
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
          <.link
            navigate={~p"/admin/sites"}
            class="px-4 py-2 bg-white dark:bg-gray-100 text-indigo-600 dark:text-indigo-700 rounded hover:bg-indigo-50 dark:hover:bg-gray-200 font-semibold transition-colors"
          >
            Go to Admin Panel
          </.link>
        </div>
      <% end %>

      <div class="bg-white dark:bg-gray-800 rounded-lg shadow dark:shadow-gray-900/50 p-6 border border-transparent dark:border-gray-700">
        <%= if @single_site do %>
          <%!-- Single site: show upload form inline --%>
          <div class="mb-6">
            <h2 class="text-2xl font-semibold mb-2 text-gray-900 dark:text-gray-100">
              {@single_site.name}
            </h2>
            <a
              href={"https://#{Upload.Sites.Site.full_domain(@single_site)}"}
              target="_blank"
              rel="noopener noreferrer"
              class="inline-flex items-center gap-2 text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-300 underline font-mono text-sm"
            >
              <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
              {Upload.Sites.Site.full_domain(@single_site)}
            </a>
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
              <div
                :for={site <- @sites}
                class="bg-indigo-50 dark:bg-indigo-950/50 border border-indigo-200 dark:border-indigo-800 rounded-lg p-6 hover:bg-indigo-100 dark:hover:bg-indigo-900/50 transition-colors"
              >
                <h3 class="text-lg font-semibold mb-2 text-gray-900 dark:text-gray-100">
                  {site.name}
                </h3>
                <div class="flex flex-col gap-2">
                  <a
                    href={"https://#{Upload.Sites.Site.full_domain(site)}"}
                    target="_blank"
                    rel="noopener noreferrer"
                    class="inline-flex items-center gap-2 text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-300 underline font-mono text-sm"
                  >
                    <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
                    {Upload.Sites.Site.full_domain(site)}
                  </a>
                  <.link
                    navigate={~p"/sites/#{site.id}/upload"}
                    class="inline-flex items-center gap-2 text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors"
                  >
                    <.icon name="hero-arrow-up-tray" class="w-4 h-4" /> Upload
                  </.link>
                </div>
              </div>
            </div>
          <% else %>
            <div class="bg-gray-50 dark:bg-gray-900/50 border border-gray-200 dark:border-gray-700 rounded-lg p-6">
              <p class="text-gray-600 dark:text-gray-400">
                You haven't been assigned to any sites yet. Please contact an administrator to get access.
              </p>
            </div>
          <% end %>
        <% end %>
      </div>

      <div class="mt-8 bg-white dark:bg-gray-800 rounded-lg shadow dark:shadow-gray-900/50 p-6 border border-transparent dark:border-gray-700">
        <h2 class="text-2xl font-semibold mb-4 text-gray-900 dark:text-gray-100">
          Account Information
        </h2>
        <div class="space-y-3">
          <div class="flex items-center gap-3">
            <img
              src={@current_user.avatar_url}
              alt={@current_user.name}
              class="w-16 h-16 rounded-full ring-2 ring-gray-200 dark:ring-gray-700"
            />
            <div>
              <p class="font-semibold text-gray-900 dark:text-gray-100">
                {@current_user.name}
              </p>
              <p class="text-sm text-gray-600 dark:text-gray-400">{@current_user.email}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
