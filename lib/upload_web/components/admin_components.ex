defmodule UploadWeb.AdminComponents do
  @moduledoc """
  Reusable components for admin pages to ensure consistency.
  """
  use Phoenix.Component

  # Import verified routes for ~p sigil
  use Phoenix.VerifiedRoutes,
    endpoint: UploadWeb.Endpoint,
    router: UploadWeb.Router,
    statics: UploadWeb.static_paths()

  # Alias Layouts module
  alias UploadWeb.Layouts

  @doc """
  Renders the admin page layout with consistent structure.

  ## Examples

      <.admin_layout current_user={@current_user} flash={@flash} page_title="Manage Sites" active_tab="sites">
        <:actions>
          <button>Custom Action</button>
        </:actions>

        Page content goes here
      </.admin_layout>
  """
  attr :current_user, :map, required: true
  attr :flash, :map, required: true
  attr :page_title, :string, required: true
  attr :active_tab, :string, required: true
  attr :class, :string, default: nil

  slot :actions, doc: "Optional action buttons for the header"
  slot :inner_block, required: true

  def admin_layout(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-7xl py-8 px-4">
        <h1 class="text-4xl font-bold mb-8 text-gray-900 dark:text-gray-100">Admin Portal</h1>

        <.admin_nav active={@active_tab} />

        <div class={[
          "bg-white dark:bg-gray-800 rounded-lg shadow dark:shadow-gray-900/50 p-6 border border-transparent dark:border-gray-700",
          @class
        ]}>
          <div class="flex justify-between items-center mb-6">
            <h2 class="text-2xl font-semibold text-gray-900 dark:text-gray-100">{@page_title}</h2>
            <div :if={@actions != []} class="flex gap-2">
              {render_slot(@actions)}
            </div>
          </div>

          {render_slot(@inner_block)}
        </div>
      </div>
    </Layouts.app>
    """
  end

  @doc """
  Renders the admin navigation tabs.
  """
  attr :active, :string, required: true

  def admin_nav(assigns) do
    ~H"""
    <div class="flex gap-2 mb-6 border-b border-gray-200 dark:border-gray-700">
      <.admin_nav_link navigate={~p"/admin/sites"} active={@active == "sites"}>
        Manage Sites
      </.admin_nav_link>
      <.admin_nav_link navigate={~p"/admin/users"} active={@active == "users"}>
        Assign Users
      </.admin_nav_link>
    </div>
    """
  end

  attr :navigate, :string, required: true
  attr :active, :boolean, default: false
  slot :inner_block, required: true

  defp admin_nav_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class={[
        "px-4 py-2 font-heading font-semibold transition-colors",
        if(@active,
          do: "border-b-2 border-primary dark:border-primary",
          else: "text-secondary dark:text-secondary hover:text-primary dark:hover:text-primary"
        )
      ]}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  Renders a table with consistent admin styling.
  """
  attr :id, :string, required: true
  attr :stream_update, :boolean, default: false

  slot :header, required: true do
    attr :label, :string, required: true
  end

  slot :row, required: true

  def admin_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200 dark:divide-gray-700">
        <thead class="bg-gray-50 dark:bg-gray-900/50">
          <tr>
            <th
              :for={header <- @header}
              class="px-6 py-3 text-left text-xs font-medium text-gray-500 dark:text-gray-400 uppercase tracking-wider"
            >
              {header.label}
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={if @stream_update, do: "stream", else: nil}
          class="bg-white dark:bg-gray-800 divide-y divide-gray-200 dark:divide-gray-700"
        >
          {render_slot(@row)}
        </tbody>
      </table>
    </div>
    """
  end
end
