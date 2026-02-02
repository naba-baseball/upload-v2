defmodule UploadWeb.SiteWebhooksLive do
  use UploadWeb, :live_view

  alias Upload.Sites
  alias Upload.Sites.SiteWebhook
  alias Upload.Webhooks

  @impl true
  def mount(%{"site_id" => site_id}, _session, socket) do
    site = Sites.get_site!(site_id)

    # Verify user has access to this site
    if Sites.user_assigned_to_site?(socket.assigns.current_user.id, site_id) do
      socket =
        socket
        |> assign(:page_title, "Webhooks - #{site.name}")
        |> assign(:site, site)
        |> assign(:webhooks, Webhooks.list_site_webhooks(site_id))
        |> assign(:editing_webhook, nil)
        |> assign(:form, to_form(%{}))
        |> assign(:test_result, nil)
        |> assign(:testing_webhook_id, false)

      {:ok, socket, layout: {UploadWeb.Layouts, :app}}
    else
      {:ok,
       socket
       |> put_flash(:error, "You don't have access to this site")
       |> push_navigate(to: ~p"/dashboard")}
    end
  end

  @impl true
  def handle_event("new", _params, socket) do
    # Initialize form with default values
    form_data = %{
      "url" => "",
      "description" => "",
      "events" => ["deployment.success"],
      "is_active" => true,
      "role_mention" => nil
    }

    socket =
      socket
      |> assign(:editing_webhook, %SiteWebhook{})
      |> assign(:form, to_form(form_data, as: :site_webhook))

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    webhook = Webhooks.get_webhook!(id)

    # Create a map with all the webhook data for the form
    form_data = %{
      "url" => webhook.url,
      "description" => webhook.description,
      "events" => webhook.events,
      "is_active" => webhook.is_active,
      "role_mention" => webhook.role_mention
    }

    socket =
      socket
      |> assign(:editing_webhook, webhook)
      |> assign(:form, to_form(form_data, as: :site_webhook))

    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel", _params, socket) do
    {:noreply, assign(socket, :editing_webhook, nil)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    webhook = Webhooks.get_webhook!(id)
    {:ok, _} = Webhooks.delete_webhook(webhook)

    {:noreply,
     socket
     |> assign(:webhooks, Webhooks.list_site_webhooks(socket.assigns.site.id))
     |> put_flash(:info, "Webhook deleted")}
  end

  @impl true
  def handle_event("toggle", %{"id" => id}, socket) do
    webhook = Webhooks.get_webhook!(id)
    {:ok, _updated} = Webhooks.update_webhook(webhook, %{is_active: !webhook.is_active})

    {:noreply,
     socket
     |> assign(:webhooks, Webhooks.list_site_webhooks(socket.assigns.site.id))}
  end

  @impl true
  def handle_event("save", %{"site_webhook" => params}, socket) do
    events =
      case params["events"] do
        list when is_list(list) -> list
        _ -> []
      end

    attrs = %{
      url: params["url"],
      description: params["description"],
      events: events,
      is_active: params["is_active"] == "true",
      role_mention: parse_role_mention(params["role_mention"])
    }

    result =
      if socket.assigns.editing_webhook.id do
        Webhooks.update_webhook(socket.assigns.editing_webhook, attrs)
      else
        Webhooks.create_webhook(socket.assigns.site.id, attrs)
      end

    case result do
      {:ok, _webhook} ->
        {:noreply,
         socket
         |> assign(:webhooks, Webhooks.list_site_webhooks(socket.assigns.site.id))
         |> assign(:editing_webhook, nil)
         |> put_flash(:info, "Webhook saved")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> assign(:editing_webhook, %{
           socket.assigns.editing_webhook
           | role_mention: params["role_mention"]
         })}
    end
  end

  @impl true
  def handle_event("test_webhook", _params, socket) do
    # Build a temporary webhook struct from form data for testing
    form = socket.assigns.form

    url = form[:url].value
    role_mention = parse_role_mention(form[:role_mention].value)
    events = form[:events].value || []

    # Validate URL is present
    if is_nil(url) || url == "" do
      {:noreply,
       socket
       |> put_flash(:error, "Please enter a webhook URL to test")
       |> assign(:test_result, %{success: false, error: "Webhook URL is required"})}
    else
      temp_webhook = %SiteWebhook{
        url: url,
        role_mention: role_mention,
        events: events
      }

      socket = assign(socket, :testing_webhook, true)

      case Webhooks.test_webhook(temp_webhook, socket.assigns.site) do
        {:ok, status, body} ->
          {:noreply,
           socket
           |> assign(:testing_webhook, false)
           |> assign(:test_result, %{success: true, status: status, body: body})}

        {:error, reason} ->
          {:noreply,
           socket
           |> assign(:testing_webhook, false)
           |> assign(:test_result, %{success: false, error: reason})}
      end
    end
  end

  @impl true
  def handle_event("clear_test_result", _params, socket) do
    {:noreply, assign(socket, :test_result, nil)}
  end

  defp parse_role_mention(nil), do: nil
  defp parse_role_mention(""), do: nil

  defp parse_role_mention(role_mention) when is_binary(role_mention) do
    String.trim(role_mention)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-4xl py-8 px-4">
      <div class="mb-8 flex items-center justify-between">
        <div>
          <h1 class="text-3xl font-bold text-gray-900 dark:text-gray-100">
            {@site.name} Webhooks
          </h1>
          <p class="text-gray-600 dark:text-gray-400 mt-1">
            Configure notifications for deployment events
          </p>
        </div>
        <.link navigate={~p"/dashboard"} class="text-indigo-600 hover:text-indigo-700 font-medium">
          ← Back to Dashboard
        </.link>
      </div>

      <%= if @editing_webhook do %>
        <.webhook_form form={@form} webhook={@editing_webhook} />
      <% else %>
        <.webhooks_list
          webhooks={@webhooks}
          site={@site}
          test_result={@test_result}
          testing_webhook_id={@testing_webhook_id}
        />
      <% end %>
    </div>
    """
  end

  defp webhook_form(assigns) do
    ~H"""
    <.card variant="white">
      <h2 class="text-xl font-semibold mb-4 text-gray-900 dark:text-gray-100">
        {if @webhook.id, do: "Edit Webhook", else: "New Webhook"}
      </h2>

      <.form for={@form} id="webhook-form" phx-submit="save" class="space-y-6">
        <div>
          <.input
            field={@form[:url]}
            type="url"
            label="Webhook URL"
            placeholder="https://discord.com/api/webhooks/..."
            required
          />
          <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
            For Discord, copy the webhook URL from:
          </p>
          <ol class="text-sm text-gray-500 dark:text-gray-400 mt-1">
            <li> (hover over a channel) Edit channel > Integrations > Webhooks </li>
          </ol>
        </div>

        <div>
          <.input
            field={@form[:description]}
            type="text"
            label="Description (optional)"
            placeholder="e.g., Discord #deployments channel"
          />
        </div>

        <div class="pt-4 border-t border-gray-200 dark:border-gray-700">
          <.input
            field={@form[:role_mention]}
            type="text"
            label="Role Mention (optional)"
            placeholder="@everyone or <@&123456789>"
          />
          <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
            Mention a role when webhook fires. Examples: <code class="bg-gray-100 dark:bg-gray-700 px-1 py-0.5 rounded">@everyone</code>, <code class="bg-gray-100 dark:bg-gray-700 px-1 py-0.5 rounded">@here</code>, or a user/role ID like
            <code class="bg-gray-100 dark:bg-gray-700 px-1 py-0.5 rounded">
              &lt;@&amp;123456789&gt;
            </code>
          </p>
        </div>

        <div>
          <span class="label">Events</span>
          <div class="space-y-2 mt-2">
            <label class="flex items-center gap-2">
              <input
                type="checkbox"
                name="site_webhook[events][]"
                value="deployment.success"
                checked={"deployment.success" in (@form[:events].value || [])}
                class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
              />
              <span class="text-gray-700 dark:text-gray-300">Deployment Successful</span>
            </label>
            <label class="flex items-center gap-2">
              <input
                type="checkbox"
                name="site_webhook[events][]"
                value="deployment.failed"
                checked={"deployment.failed" in (@form[:events].value || [])}
                class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
              />
              <span class="text-gray-700 dark:text-gray-300">Deployment Failed</span>
            </label>
          </div>
        </div>

        <div>
          <label class="flex items-center gap-2">
            <input
              type="checkbox"
              name="site_webhook[is_active]"
              value="true"
              checked={@form[:is_active].value}
              class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
            />
            <span class="text-gray-700 dark:text-gray-300">Active</span>
          </label>
        </div>

        <div class="flex gap-4 pt-4">
          <.button type="submit">Save Webhook</.button>
          <.button type="button" variant="secondary" phx-click="cancel">Cancel</.button>
        </div>
      </.form>
    </.card>
    """
  end

  defp webhooks_list(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="flex justify-between items-center">
        <h2 class="text-xl font-semibold text-gray-900 dark:text-gray-100">Configured Webhooks</h2>
        <.button phx-click="new" variant="secondary">+ Add Webhook</.button>
      </div>

      <%= if @webhooks == [] do %>
        <.card variant="white">
          <.empty_state icon="hero-bell-slash">
            No webhooks configured. Add a webhook to receive deployment notifications.
          </.empty_state>
        </.card>
      <% else %>
        <div class="space-y-4">
          <.card :for={webhook <- @webhooks} variant="white" class="p-6">
            <div class="flex items-start justify-between">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-3 mb-2">
                  <h3 class="font-semibold text-gray-900 dark:text-gray-100 truncate">
                    {webhook.description || webhook.url}
                  </h3>
                </div>

                <p class="text-sm text-gray-600 dark:text-gray-400 font-mono truncate mb-2">
                  {webhook.url}
                </p>

                <div class="flex items-center gap-4 text-sm text-gray-500 dark:text-gray-400">
                  <span>
                    Events: {Enum.join(webhook.events, ", ")}
                  </span>
                  <%= if webhook.last_triggered_at do %>
                    <span>
                      Last triggered: {Calendar.strftime(
                        webhook.last_triggered_at,
                        "%Y-%m-%d %H:%M UTC"
                      )}
                    </span>
                  <% end %>
                </div>

                <%= if webhook.last_response_status do %>
                  <div class={[
                    "mt-3 p-3 rounded text-sm",
                    response_status_class(webhook.last_response_status)
                  ]}>
                    <div class="font-medium mb-1">
                      Last Response: {webhook.last_response_status}
                    </div>
                    <%= if webhook.last_response_body do %>
                      <pre class="text-xs overflow-x-auto whitespace-pre-wrap font-mono mt-1 opacity-75"><%= webhook.last_response_body %></pre>
                    <% end %>
                  </div>
                <% end %>
              </div>

              <div class="flex items-center gap-2 ml-4">
                <button
                  phx-click="toggle"
                  phx-value-id={webhook.id}
                  class={[
                    "flex items-center gap-2 px-3 py-1.5 rounded-full text-sm font-medium transition-colors",
                    if(webhook.is_active,
                      do:
                        "bg-green-100 text-green-700 dark:bg-green-900 dark:text-green-300 hover:bg-green-200 dark:hover:bg-green-800",
                      else:
                        "bg-gray-100 text-gray-600 dark:bg-gray-700 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-600"
                    )
                  ]}
                  title={if webhook.is_active, do: "Click to disable", else: "Click to enable"}
                >
                  <span class={[
                    "relative inline-flex h-5 w-9 shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out",
                    webhook.is_active && "bg-green-500",
                    !webhook.is_active && "bg-gray-300 dark:bg-gray-500"
                  ]}>
                    <span class={[
                      "pointer-events-none inline-block h-4 w-4 transform rounded-full bg-white shadow ring-0 transition duration-200 ease-in-out",
                      webhook.is_active && "translate-x-4",
                      !webhook.is_active && "translate-x-0"
                    ]} />
                  </span>
                  <span>{if webhook.is_active, do: "On", else: "Off"}</span>
                </button>
                <button
                  phx-click="edit"
                  phx-value-id={webhook.id}
                  class="p-2 text-gray-400 hover:text-indigo-600 dark:hover:text-indigo-400"
                  title="Edit"
                >
                  <.icon name="hero-pencil" class="w-5 h-5" />
                </button>
                <button
                  phx-click="delete"
                  phx-value-id={webhook.id}
                  data-confirm="Are you sure you want to delete this webhook?"
                  class="p-2 text-gray-400 hover:text-red-600 dark:hover:text-red-400"
                  title="Delete"
                >
                  <.icon name="hero-trash" class="w-5 h-5" />
                </button>
              </div>
            </div>
          </.card>
        </div>
      <% end %>
    </div>
    """
  end

  defp response_status_class(status) when status >= 200 and status < 300,
    do: "bg-green-50 text-green-800 dark:bg-green-900/20 dark:text-green-200"

  defp response_status_class(_status),
    do: "bg-red-50 text-red-800 dark:bg-red-900/20 dark:text-red-200"
end
