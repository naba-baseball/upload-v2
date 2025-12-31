defmodule UploadWeb.DashboardLive do
  use UploadWeb, :live_view

  alias Upload.Accounts

  @impl true
  def mount(_params, _session, socket) do
    user = Accounts.get_user_with_sites!(socket.assigns.current_user.id)

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:sites, user.sites), layout: {UploadWeb.Layouts, :app}}
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
              <a
                href={"https://#{Upload.Sites.Site.full_domain(site)}"}
                target="_blank"
                rel="noopener noreferrer"
                class="inline-flex items-center gap-2 text-indigo-600 dark:text-indigo-400 hover:text-indigo-800 dark:hover:text-indigo-300 underline font-mono text-sm"
              >
                <.icon name="hero-arrow-top-right-on-square" class="w-4 h-4" />
                {Upload.Sites.Site.full_domain(site)}
              </a>
            </div>
          </div>
        <% else %>
          <div class="bg-gray-50 dark:bg-gray-900/50 border border-gray-200 dark:border-gray-700 rounded-lg p-6">
            <p class="text-gray-600 dark:text-gray-400">
              You haven't been assigned to any sites yet. Please contact an administrator to get access.
            </p>
          </div>
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
