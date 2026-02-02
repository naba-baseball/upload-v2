defmodule UploadWeb.HomeLive do
  @moduledoc """
  Public home page displaying all deployed sites.
  """
  use UploadWeb, :live_view

  import Ecto.Query
  import UploadWeb.UploadComponents

  alias Upload.Repo
  alias Upload.Sites.Site

  @impl true
  def mount(_params, _session, socket) do
    sites =
      from(s in Site,
        where: s.deployment_status == "deployed",
        order_by: [asc: s.name]
      )
      |> Repo.all()

    {:ok, assign(socket, :sites, sites), layout: {UploadWeb.Layouts, :home}}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col">
      <main class="flex-grow px-4 py-12 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-4xl">
          <div class="text-center mb-12">
            <h1 class="text-4xl font-bold mb-4 text-gray-900 dark:text-gray-100">
              OOTP Sites
            </h1>
          </div>

          <%= if @sites == [] do %>
            <div class="text-center py-16">
              <div class="text-gray-400 dark:text-gray-600 mb-4">
                <.icon name="hero-globe-alt" class="w-16 h-16 mx-auto" />
              </div>
              <p class="text-gray-600 dark:text-gray-400 text-lg">
                No sites deployed yet. Check back soon!
              </p>
            </div>
          <% else %>
            <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <div
                :for={site <- @sites}
                class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700 p-6 hover:shadow-md transition-shadow"
              >
                <h3 class="text-lg font-semibold mb-3 text-gray-900 dark:text-gray-100">
                  {site.name}
                </h3>
                <.site_url_links site={site} icon="hero-arrow-top-right-on-square" />
              </div>
            </div>
          <% end %>
        </div>
      </main>

      <footer class="border-t border-gray-200 dark:border-gray-800 py-6 px-4">
        <div class="mx-auto max-w-4xl flex sm:flex-row items-center justify-between sm:justify-end gap-4">
          <.link
            navigate={~p"/dashboard"}
            class="inline-flex justify-end items-center gap-2 text-sm font-medium hover:text-accent"
          >
            Manage your site <.icon name="hero-arrow-right" class="w-4 h-4" />
          </.link>
        </div>
      </footer>
    </div>
    """
  end
end
