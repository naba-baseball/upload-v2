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
    <div class="min-h-screen flex flex-col bg-base-100">
      <main class="flex-grow px-4 py-12 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-4xl animate-vintage-fade-in">
          <%!-- Page Header with Vintage Ornaments --%>
          <div class="text-center mb-12">
            <div class="vintage-ornament mb-6">
              <div class="vintage-ornament-diamond"></div>
            </div>
            <h1 class="font-display text-4xl sm:text-5xl text-primary mb-2">
              OOTP Sites
            </h1>
            <p class="font-body text-secondary text-lg">
              Browse all deployed baseball sites
            </p>
            <div class="vintage-ornament mt-6">
              <div class="vintage-ornament-diamond"></div>
            </div>
          </div>

          <%= if @sites == [] do %>
            <%!-- Vintage Empty State --%>
            <div class="vintage-card text-center py-16 px-8">
              <div class="inline-flex items-center justify-center w-20 h-20 bg-primary/10 rounded-full mb-6">
                <.icon name="hero-globe-alt" class="w-10 h-10 text-primary" />
              </div>
              <h3 class="font-display text-2xl mb-3 text-primary">No Sites Yet</h3>
              <p class="font-body text-secondary text-lg max-w-md mx-auto">
                No sites deployed yet. Check back soon!
              </p>
            </div>
          <% else %>
            <%!-- Vintage Site Cards Grid --%>
            <div class="grid gap-6 sm:grid-cols-2 lg:grid-cols-3 stagger-children">
              <div
                :for={site <- @sites}
                class="vintage-card card-hover corner-decoration p-6"
              >
                <div class="mb-4">
                  <h3 class="font-display text-xl text-primary mb-2">
                    {site.name}
                  </h3>
                  <div class="h-1 w-16 bg-accent rounded-full"></div>
                </div>
                <.site_url_links site={site} icon="hero-arrow-top-right-on-square" />
              </div>
            </div>
          <% end %>

          <%!-- Manage Sites CTA --%>
          <div class="mt-12 text-center">
            <div class="vintage-ornament mb-6">
              <div class="vintage-ornament-diamond"></div>
            </div>
            <.link
              navigate={~p"/dashboard"}
              class="vintage-btn vintage-btn-secondary inline-flex items-center gap-2"
            >
              <.icon name="hero-arrow-right" class="w-4 h-4" />
              <span class="font-display">Manage Your Site</span>
            </.link>
          </div>
        </div>
      </main>
    </div>
    """
  end
end
