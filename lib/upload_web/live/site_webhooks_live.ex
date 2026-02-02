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
  def handle_event("test_webhook", %{"id" => id}, socket) do
    webhook = Webhooks.get_webhook!(id)

    socket = assign(socket, :testing_webhook_id, id)

    case Webhooks.test_webhook(webhook, socket.assigns.site) do
      {:ok, status, body} ->
        {:noreply,
         socket
         |> assign(:testing_webhook_id, nil)
         |> assign(:test_result, %{webhook_id: id, success: true, status: status, body: body})}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:testing_webhook_id, nil)
         |> assign(:test_result, %{webhook_id: id, success: false, error: reason})}
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
    <div>
      <div class="vintage-ornament mb-6">
        <div class="vintage-ornament-diamond"></div>
      </div>

      <div class="text-center mb-8">
        <h1 class="font-display text-3xl mb-2">{@site.name} Webhooks</h1>
        <p class="text-secondary">Configure notifications for deployment events</p>
        <div class="mt-6">
          <.link
            navigate={~p"/dashboard"}
            class="inline-flex items-center gap-1 text-secondary hover:text-primary transition-colors"
          >
            <.icon name="hero-arrow-left" class="w-4 h-4" /> Back to Dashboard
          </.link>
        </div>
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
    <div class="vintage-card p-8">
      <div class="vintage-ornament mb-4">
        <div class="vintage-ornament-diamond"></div>
      </div>
      <h2 class="font-display text-2xl text-center mb-6">
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
          <p class="text-sm text-secondary mt-1">
            For Discord, copy the webhook URL from:
          </p>
          <ol class="text-sm text-secondary mt-1">
            <li>(hover over a channel) Edit channel > Integrations > Webhooks</li>
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

        <div class="pt-4 border-t-2 border-primary/20">
          <.input
            field={@form[:role_mention]}
            type="text"
            label="Role Mention (optional)"
            placeholder="@everyone or <@&123456789>"
          />
          <p class="text-sm text-secondary mt-1">
            Mention a role when webhook fires. Examples: <code class="bg-base-200 px-1 py-0.5 rounded">@everyone</code>, <code class="bg-base-200 px-1 py-0.5 rounded">@here</code>, or a user/role ID like
            <code class="bg-base-200 px-1 py-0.5 rounded">
              &lt;@&amp;123456789&gt;
            </code>
          </p>
        </div>

        <div>
          <span class="label font-display text-base-content">Events</span>
          <div class="space-y-2 mt-2">
            <label class="flex items-center gap-2">
              <input
                type="checkbox"
                name="site_webhook[events][]"
                value="deployment.success"
                checked={"deployment.success" in (@form[:events].value || [])}
                class="rounded border-gray-300 checkbox-checkbox-sm"
              />
              <span class="text-base-content">Deployment Successful</span>
            </label>
            <label class="flex items-center gap-2">
              <input
                type="checkbox"
                name="site_webhook[events][]"
                value="deployment.failed"
                checked={"deployment.failed" in (@form[:events].value || [])}
                class="rounded border-gray-300 checkbox-checkbox-sm"
              />
              <span class="text-base-content">Deployment Failed</span>
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
              class="rounded checkbox-checkbox-sm"
            />
            <span class="text-base-content">Active</span>
          </label>
        </div>

        <div class="flex gap-4 pt-4">
          <.button type="submit">Save Webhook</.button>
          <.button type="button" variant="secondary" phx-click="cancel">Cancel</.button>
        </div>
      </.form>
    </div>
    """
  end

  defp webhooks_list(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="vintage-card p-6">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-3">
            <.icon name="hero-bell-alert" class="w-8 h-8 text-primary" />
            <h2 class="font-display text-xl">Configured Webhooks</h2>
          </div>
          <.button phx-click="new" variant="secondary">
            <.icon name="hero-plus" class="w-4 h-4" /> Add Webhook
          </.button>
        </div>
      </div>

      <%= if @webhooks == [] do %>
        <div class="vintage-card text-center py-12">
          <.icon name="hero-bell-slash" class="w-16 h-16 text-primary/50 mx-auto mb-6" />
          <h3 class="font-display text-2xl mb-4">No Webhooks Yet</h3>
          <p class="text-secondary max-w-md mx-auto">
            No webhooks configured. Add a webhook to receive deployment notifications.
          </p>
        </div>
      <% else %>
        <div class="grid gap-4">
          <.card :for={webhook <- @webhooks} class="vintage-card">
            <div class="flex items-start justify-between">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-4 mb-4">
                  <.icon
                    name={webhook_icon(webhook)}
                    class={["w-8 h-8", webhook.is_active && "text-primary"]}
                  />
                  <div class="flex-1 min-w-0">
                    <h3 class="font-display text-lg mb-1">
                      {webhook.description || truncate_url(webhook.url)}
                    </h3>
                    <p class="text-sm text-secondary font-body truncate" title={webhook.url}>
                      {webhook.url}
                    </p>
                  </div>
                </div>

                <div class="space-y-2 mb-4 text-sm text-secondary">
                  <div class="flex items-center gap-2">
                    <.icon name="hero-bell" class="w-4 h-4" />
                    <span>Events: {Enum.join(webhook.events, ", ")}</span>
                  </div>
                  <%= if webhook.last_triggered_at do %>
                    <div class="flex items-center gap-2">
                      <.icon name="hero-clock" class="w-4 h-4" />
                      <span
                        id={"webhook-trigger-#{webhook.id}"}
                        phx-hook="LocalTime"
                        data-timestamp={webhook.last_triggered_at}
                        data-label="Last triggered"
                      >
                      </span>
                    </div>
                  <% end %>
                </div>

                <%= if webhook.last_response_status do %>
                  <% is_success =
                    webhook.last_response_status >= 200 and webhook.last_response_status < 300 %>
                  <div class={[
                    "mt-3 p-3 rounded text-sm vintage-surface",
                    !is_success && "border-error"
                  ]}>
                    <div class={["font-medium mb-1", is_success && "text-success"]}>
                      Last Response: {webhook.last_response_status}
                    </div>
                    <%= if webhook.last_response_body do %>
                      <pre class="text-xs overflow-x-auto whitespace-pre-wrap font-mono bg-base-100 p-2 rounded"><%= webhook.last_response_body %></pre>
                    <% end %>
                  </div>
                <% end %>

                <%= if @test_result && @test_result.webhook_id == webhook.id do %>
                  <div class={[
                    "mt-3 p-3 rounded text-sm vintage-surface",
                    @test_result.success || "border-error"
                  ]}>
                    <div class="flex items-start justify-between">
                      <div class={["font-medium mb-1", @test_result.success && "text-success"]}>
                        <%= if @test_result.success do %>
                          Test Successful - Status {@test_result.status}
                        <% else %>
                          Test Failed
                        <% end %>
                      </div>
                      <%= if @test_result.success && @test_result.body do %>
                        <pre class="text-xs overflow-x-auto whitespace-pre-wrap font-mono bg-base-100 p-2 rounded mt-2"><%= @test_result.body %></pre>
                      <% end %>
                      <%= if !@test_result.success do %>
                        <p class="text-xs text-error mt-2">{@test_result.error}</p>
                      <% end %>
                    </div>
                  </div>
                <% end %>
              </div>

              <div class="flex items-center gap-2 ml-4 flex-col w-28">
                <%= if @test_result && @test_result.webhook_id == webhook.id do %>
                  <.button
                    phx-click="clear_test_result"
                    variant={if @test_result.success, do: "success", else: "danger"}
                    size="sm"
                    class="w-full"
                  >
                    <%= if @test_result.success do %>
                      <.icon name="hero-check" class="w-4 h-4" /> OK
                    <% else %>
                      <.icon name="hero-x-mark" class="w-4 h-4" /> Fail
                    <% end %>
                  </.button>
                <% end %>

                <%= if @testing_webhook_id == webhook.id do %>
                  <.button disabled variant="primary" size="sm" class="w-full">
                    <.icon name="hero-arrow-path" class="w-4 h-4 animate-spin" /> Test...
                  </.button>
                <% else %>
                  <.button
                    phx-click="test_webhook"
                    phx-value-id={webhook.id}
                    variant="primary"
                    size="sm"
                    class="w-full"
                  >
                    <.icon name="hero-bolt" class="w-4 h-4" /> Test
                  </.button>
                <% end %>

                <.button
                  phx-click="toggle"
                  phx-value-id={webhook.id}
                  variant={if webhook.is_active, do: "success", else: "secondary"}
                  size="sm"
                  class="w-full"
                >
                  {if webhook.is_active, do: "Active", else: "Inactive"}
                </.button>

                <div class="flex gap-1 w-full border-t border-primary/10 pt-2 justify-center">
                  <button
                    phx-click="edit"
                    phx-value-id={webhook.id}
                    class="p-2 text-secondary hover:text-primary"
                  >
                    <.icon name="hero-pencil" class="w-5 h-5" />
                  </button>
                  <button
                    phx-click="delete"
                    phx-value-id={webhook.id}
                    data-confirm="Are you sure you want to delete this webhook?"
                    class="p-2 text-secondary hover:text-error"
                  >
                    <.icon name="hero-trash" class="w-5 h-5" />
                  </button>
                </div>
              </div>
            </div>
          </.card>
        </div>
      <% end %>
    </div>
    """
  end

  defp webhook_icon(%{is_active: true}), do: "hero-bell"
  defp webhook_icon(%{is_active: false}), do: "hero-bell-slash"

  defp truncate_url(url, max_length \\ 50) do
    if String.length(url) > max_length do
      String.slice(url, 0, max_length) <> "..."
    else
      url
    end
  end
end
