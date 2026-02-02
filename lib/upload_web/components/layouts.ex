defmodule UploadWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use UploadWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_user, :map, default: nil
  attr :inner_content, :any, default: nil
  slot :inner_block

  def app(assigns) do
    ~H"""
    <header class="border-b-4 border-primary bg-base-100">
      <div class="px-4 sm:px-6 lg:px-8 py-4">
        <div class="flex items-center justify-between">
          <%!-- Logo Section --%>
          <a href="/" class="flex items-center gap-3 group">
            <%!-- Baseball Diamond Icon --%>
            <div class="relative w-10 h-10 flex items-center justify-center">
              <svg
                viewBox="0 0 100 100"
                class="w-full h-full text-primary group-hover:text-accent transition-colors duration-300"
              >
                <%!-- Diamond shape --%>
                <polygon
                  points="50,5 95,50 50,95 5,50"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="4"
                />
                <%!-- Baseball stitches --%>
                <path
                  d="M30 30 Q50 50 30 70"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-dasharray="4,3"
                />
                <path
                  d="M70 30 Q50 50 70 70"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-dasharray="4,3"
                />
                <%!-- Center dot --%>
                <circle cx="50" cy="50" r="6" fill="currentColor" />
              </svg>
            </div>
            <div class="flex flex-col">
              <span class="font-display text-xl sm:text-2xl text-primary tracking-wide leading-none">
                NABA
              </span>
              <span class="font-heading text-xs sm:text-sm text-neutral tracking-widest uppercase">
                Upload Portal
              </span>
            </div>
          </a>

          <%!-- Navigation Section --%>
          <div class="flex items-center gap-4">
            <%!-- Theme Toggle with Vintage Styling --%>
            <div class="hidden sm:block">
              <.theme_toggle />
            </div>

            <%!-- Ornamental Divider --%>
            <div class="hidden md:flex items-center gap-2 text-primary">
              <div class="w-px h-8 bg-primary opacity-30"></div>
            </div>

            <%= if @current_user do %>
              <div class="flex items-center gap-3">
                <%!-- User Avatar with Baseball Frame --%>
                <div class="hidden sm:flex items-center gap-2">
                  <%= if @current_user.avatar_url do %>
                    <img
                      src={@current_user.avatar_url}
                      alt={@current_user.name}
                      class="w-10 h-10 rounded-full border-3 border-primary shadow-md"
                    />
                  <% end %>
                  <div class="flex flex-col text-right">
                    <span class="font-heading text-sm font-bold text-base-content leading-tight">
                      {@current_user.name}
                    </span>
                    <span class="text-xs text-neutral uppercase tracking-wider">
                      {if @current_user.role == "admin", do: "Manager", else: "Player"}
                    </span>
                  </div>
                </div>

                <%!-- Sign Out Button --%>
                <a
                  href={~p"/auth/signout"}
                  class="vintage-btn vintage-btn-secondary btn-sm px-4"
                >
                  <.icon name="hero-arrow-right-on-rectangle" class="w-4 h-4 sm:mr-2" />
                  <span class="hidden sm:inline">Sign Out</span>
                </a>
              </div>
            <% else %>
              <%!-- Sign In Button --%>
              <a
                href={~p"/auth/discord"}
                class="vintage-btn vintage-btn-primary btn-sm px-6"
              >
                <.icon name="hero-user-circle" class="w-4 h-4 mr-2" />
                <span class="font-heading">Enter Ballpark</span>
              </a>
            <% end %>
          </div>
        </div>
      </div>
    </header>

    <%!-- Main Content Area with Vintage Card Container --%>
    <main class="px-4 sm:px-6 lg:px-8 py-8 sm:py-12">
      <div class="mx-auto max-w-4xl">
        <div class="vintage-card baseball-stitches p-6 sm:p-8 lg:p-12 animate-vintage-fade-in">
          {render_slot(@inner_block) || @inner_content}
        </div>
      </div>
    </main>

    <%!-- Footer with Vintage Styling --%>
    <footer class="border-t-4 border-primary bg-base-200 mt-auto">
      <div class="px-4 sm:px-6 lg:px-8 py-6">
        <div class="flex flex-col sm:flex-row items-center justify-between gap-4">
          <div class="flex items-center gap-2 text-neutral">
            <.icon name="hero-trophy" class="w-5 h-5 text-accent" />
            <span class="font-heading text-sm">Est. 1920</span>
          </div>
          <div class="vintage-ornament w-full sm:w-auto">
            <div class="vintage-ornament-diamond"></div>
          </div>
          <p class="font-body text-sm text-neutral italic">
            "America's Pastime, Digitally Preserved"
          </p>
        </div>
      </div>
    </footer>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.
  Styled with vintage baseball aesthetic - like a stadium lighting control.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="relative flex items-center bg-base-300 rounded-lg border-2 border-primary p-1 gap-1">
      <%!-- Sliding Indicator --%>
      <div class="absolute h-[calc(100%-8px)] w-[calc(33.333%-4px)] rounded-md bg-primary transition-all duration-300 ease-out
        left-1 [[data-theme-mode=system]_&]:left-1
        [[data-theme-mode=light]_&]:left-[calc(33.333%+2px)]
        [[data-theme-mode=dark]_&]:left-[calc(66.666%+3px)]" />

      <button
        class="relative z-10 flex items-center justify-center p-2 w-10 h-10 rounded-md transition-colors duration-200
          [[data-theme-mode=system]_&]:text-primary-content"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
        title="Stadium Auto-Lighting"
      >
        <.icon name="hero-computer-desktop" class="w-5 h-5" />
      </button>

      <button
        class="relative z-10 flex items-center justify-center p-2 w-10 h-10 rounded-md transition-colors duration-200
          [[data-theme-mode=light]_&]:text-primary-content"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        title="Day Game"
      >
        <.icon name="hero-sun" class="w-5 h-5" />
      </button>

      <button
        class="relative z-10 flex items-center justify-center p-2 w-10 h-10 rounded-md transition-colors duration-200
          [[data-theme-mode=dark]_&]:text-primary-content"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        title="Night Game"
      >
        <.icon name="hero-moon" class="w-5 h-5" />
      </button>
    </div>
    """
  end
end
