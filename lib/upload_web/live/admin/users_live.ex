defmodule UploadWeb.Admin.UsersLive do
  use UploadWeb, :live_view
  import UploadWeb.AdminComponents

  alias Upload.Accounts
  alias Upload.Sites

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()
    sites = Sites.list_sites()

    {:ok,
     socket
     |> assign(:sites, sites)
     |> stream(:users, users)}
  end

  @impl true
  def handle_event("toggle_user_site", %{"user-id" => user_id, "site-id" => site_id}, socket) do
    user_id = String.to_integer(user_id)
    site_id = String.to_integer(site_id)

    {:ok, updated_user} = Sites.toggle_user_site(user_id, site_id)

    {:noreply,
     socket
     |> put_flash(:info, "User site assignment updated")
     |> stream_insert(:users, updated_user)}
  end

  defp user_has_site?(user, site_id) do
    Enum.any?(user.sites, fn site -> site.id == site_id end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_layout
      current_user={@current_user}
      flash={@flash}
      page_title="Assign Users to Sites"
      active_tab="users"
    >
      <.admin_table id="users" stream_update={true}>
        <:header label="User" />
        <:header label="Email" />
        <:header label="Assigned Sites" />

        <:row>
          <tr :for={{id, user} <- @streams.users} id={id}>
            <td class="px-6 py-4 whitespace-nowrap">
              <div class="flex items-center gap-2">
                <.user_avatar user={user} size="sm" />
                <span class="font-medium text-gray-900 dark:text-gray-100">{user.name}</span>
              </div>
            </td>
            <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500 dark:text-gray-400">
              {user.email}
            </td>
            <td class="px-6 py-4">
              <div class="flex flex-wrap gap-2">
                <button
                  :for={site <- @sites}
                  type="button"
                  phx-click="toggle_user_site"
                  phx-value-user-id={user.id}
                  phx-value-site-id={site.id}
                  class={[
                    "inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-sm font-medium transition-all duration-150",
                    if(user_has_site?(user, site.id),
                      do: "bg-primary/20 dark:bg-primary/20 ring-2 ring-primary dark:ring-primary",
                      else:
                        "bg-base-200 dark:bg-base-800 text-secondary dark:text-secondary hover:bg-primary/10 dark:hover:bg-primary/10"
                    )
                  ]}
                >
                  <span class={[
                    "w-4 h-4 rounded border-2 flex items-center justify-center transition-colors",
                    if(user_has_site?(user, site.id),
                      do: "bg-primary border-primary dark:bg-primary dark:border-primary",
                      else: "border-base-300 dark:border-base-600"
                    )
                  ]}>
                    <.icon
                      :if={user_has_site?(user, site.id)}
                      name="hero-check"
                      class="w-3 h-3 text-white"
                    />
                  </span>
                  {site.name}
                </button>
              </div>
              <p
                :if={user.sites == []}
                class="text-sm text-gray-400 dark:text-gray-500 italic"
              >
                No sites assigned
              </p>
            </td>
          </tr>
        </:row>
      </.admin_table>
    </.admin_layout>
    """
  end
end
