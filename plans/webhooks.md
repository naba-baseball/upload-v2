# Webhook Feature Implementation Plan

## Overview
Add per-site webhook management that triggers on deployment success/failure. Webhooks are user-configurable with Discord support, response logging for debugging, and fire-and-forget delivery that doesn't block deployments.

## Requirements
- Users configure their own webhooks per site
- Discord webhook support with customizable payloads
- Only 2 event types: deployment.success, deployment.failed
- Log the most recent response for debugging (does not affect ongoing deployment)
- Fire-and-forget: webhook failures don't block deployments

---

## Phase 1: Database Migration

**File:** `priv/repo/migrations/20260202041001_create_site_webhooks.exs`

```elixir
defmodule Upload.Repo.Migrations.CreateSiteWebhooks do
  use Ecto.Migration

  def change do
    create table(:site_webhooks) do
      add :site_id, references(:sites, on_delete: :delete_all), null: false
      add :url, :string, null: false
      add :description, :string
      add :events, {:array, :string}, default: [], null: false
      add :payload_template, :map, default: %{}
      add :is_active, :boolean, default: true, null: false
      add :last_response_status, :integer
      add :last_response_body, :text
      add :last_triggered_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:site_webhooks, [:site_id])
    create index(:site_webhooks, [:is_active])
  end
end
```

---

## Phase 2: Schema Module

**File:** `lib/upload/sites/site_webhook.ex`

```elixir
defmodule Upload.Sites.SiteWebhook do
  use Ecto.Schema
  import Ecto.Changeset

  @events ~w(deployment.success deployment.failed)

  schema "site_webhooks" do
    field :url, :string
    field :description, :string
    field :events, {:array, :string}, default: []
    field :payload_template, :map, default: %{}
    field :is_active, :boolean, default: true
    field :last_response_status, :integer
    field :last_response_body, :string
    field :last_triggered_at, :utc_datetime

    belongs_to :site, Upload.Sites.Site

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, [:url, :description, :events, :payload_template, :is_active])
    |> validate_required([:url])
    |> validate_format(:url, ~r/^https?:\/\/.+/,
      message: "must be a valid URL starting with http:// or https://"
    )
    |> validate_subset(:events, @events)
  end

  @doc """
  Returns the list of available event types.
  """
  def available_events, do: @events
end
```

---

## Phase 3: Webhooks Context

**File:** `lib/upload/webhooks.ex`

```elixir
defmodule Upload.Webhooks do
  @moduledoc """
  Context module for managing webhooks and sending webhook notifications.
  """

  require Logger
  import Ecto.Query, warn: false
  alias Upload.Repo
  alias Upload.Sites.SiteWebhook
  alias Upload.Sites.Site

  @doc """
  Lists all webhooks for a site.
  """
  def list_site_webhooks(site_id) do
    SiteWebhook
    |> where([w], w.site_id == ^site_id)
    |> order_by([w], desc: w.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single webhook.
  Raises if not found.
  """
  def get_webhook!(id), do: Repo.get!(SiteWebhook, id)

  @doc """
  Creates a webhook.
  """
  def create_webhook(site_id, attrs) do
    %SiteWebhook{site_id: site_id}
    |> SiteWebhook.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a webhook.
  """
  def update_webhook(%SiteWebhook{} = webhook, attrs) do
    webhook
    |> SiteWebhook.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a webhook.
  """
  def delete_webhook(%SiteWebhook{} = webhook) do
    Repo.delete(webhook)
  end

  @doc """
  Triggers webhooks for a specific event on a site.
  Runs asynchronously and does not block or affect deployment.
  """
  def trigger_webhooks(%Site{} = site, event) when event in ["deployment.success", "deployment.failed"] do
    site.id
    |> list_active_webhooks_for_event(event)
    |> Enum.each(fn webhook ->
      Task.start(fn ->
        send_webhook(webhook, site, event)
      end)
    end)
  end

  defp list_active_webhooks_for_event(site_id, event) do
    SiteWebhook
    |> where([w], w.site_id == ^site_id and w.is_active == true)
    |> where([w], ^event in w.events)
    |> Repo.all()
  end

  defp send_webhook(%SiteWebhook{} = webhook, %Site{} = site, event) do
    payload = build_payload(webhook, site, event)

    Logger.info(
      event: "webhook.sending",
      webhook_id: webhook.id,
      site_id: site.id,
      event: event
    )

    case Req.post(webhook.url,
           json: payload,
           receive_timeout: 30_000,
           retry: :never
         ) do
      {:ok, %{status: status} = response} ->
        log_webhook_response(webhook, status, response.body)
        Logger.info(event: "webhook.sent", webhook_id: webhook.id, status: status)

      {:error, reason} ->
        log_webhook_response(webhook, nil, inspect(reason))
        Logger.warning(event: "webhook.failed", webhook_id: webhook.id, reason: inspect(reason))
    end
  end

  defp log_webhook_response(%SiteWebhook{} = webhook, status, body) do
    # Truncate body if too long
    body_text = if is_binary(body), do: String.slice(body, 0, 10_000), else: inspect(body)

    webhook
    |> Ecto.Changeset.change(
      last_response_status: status,
      last_response_body: body_text,
      last_triggered_at: DateTime.utc_now()
    )
    |> Repo.update()
  end

  defp build_payload(%SiteWebhook{payload_template: template}, %Site{} = site, event)
       when is_map(template) and map_size(template) > 0 do
    # Use custom template
    template
    |> interpolate_template(site, event)
  end

  defp build_payload(_webhook, %Site{} = site, event) do
    # Default Discord-compatible format
    %{
      content: nil,
      embeds: [
        %{
          title: "Deployment #{event_result(event)}",
          description: "Site **#{site.name}** has been #{event_action(event)}",
          color: event_color(event),
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          fields: [
            %{name: "Site", value: site.name, inline: true},
            %{name: "Subdomain", value: site.subdomain, inline: true},
            %{name: "Status", value: site.deployment_status, inline: true}
          ],
          url: Site.format_site_url(site)
        }
      ]
    }
  end

  defp interpolate_template(template, site, event) do
    # Simple string interpolation for template values
    template
    |> Enum.map(fn {k, v} ->
      {k, interpolate_value(v, site, event)}
    end)
    |> Enum.into(%{})
  end

  defp interpolate_value(value, site, event) when is_binary(value) do
    value
    |> String.replace("{site.name}", site.name)
    |> String.replace("{site.subdomain}", site.subdomain)
    |> String.replace("{site.deployment_status}", site.deployment_status)
    |> String.replace("{event}", event)
    |> String.replace("{timestamp}", DateTime.utc_now() |> DateTime.to_iso8601())
  end

  defp interpolate_value(value, _site, _event), do: value

  defp event_result("deployment.success"), do: "Successful"
  defp event_result("deployment.failed"), do: "Failed"

  defp event_action("deployment.success"), do: "successfully deployed"
  defp event_action("deployment.failed"), do: "deployment failed"

  defp event_color("deployment.success"), do: 0x00FF00  # Green
  defp event_color("deployment.failed"), do: 0xFF0000   # Red
end
```

---

## Phase 4: Integrate with Sites Context

**File:** `lib/upload/sites.ex` (modify `mark_deployed/1` and `mark_deployment_failed/2`)

Add webhook trigger calls after successful deployment status updates:

```elixir
@doc """
Marks a site as successfully deployed.
"""
def mark_deployed(%Site{} = site) do
  result =
    site
    |> update_deployment_status(%{
      deployment_status: "deployed",
      last_deployed_at: DateTime.utc_now(),
      last_deployment_error: nil
    })
    |> broadcast_deployment_update()

  # Trigger webhooks asynchronously - does not affect deployment
  Upload.Webhooks.trigger_webhooks(site, "deployment.success")
  
  result
end

@doc """
Marks a site deployment as failed.
"""
def mark_deployment_failed(%Site{} = site, error) do
  result =
    site
    |> update_deployment_status(%{
      deployment_status: "failed",
      last_deployment_error: format_deployment_error(error)
    })
    |> broadcast_deployment_update()

  # Trigger webhooks asynchronously - does not affect deployment
  Upload.Webhooks.trigger_webhooks(site, "deployment.failed")
  
  result
end
```

---

## Phase 5: LiveView for Webhook Management

**File:** `lib/upload_web/live/site_webhooks_live.ex`

```elixir
defmodule UploadWeb.SiteWebhooksLive do
  use UploadWeb, :live_view

  alias Upload.Sites
  alias Upload.Sites.Site
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
    {:noreply, assign(socket, :editing_webhook, %SiteWebhook{})}
  end

  @impl true
  def handle_event("edit", %{"id" => id}, socket) do
    webhook = Webhooks.get_webhook!(id)
    {:noreply, assign(socket, :editing_webhook, webhook)}
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
    {:ok, updated} = Webhooks.update_webhook(webhook, %{is_active: !webhook.is_active})

    {:noreply,
     socket
     |> assign(:webhooks, Webhooks.list_site_webhooks(socket.assigns.site.id))
     |> put_flash(:info, "Webhook #{if updated.is_active, do: "enabled", else: "disabled"}")}
  end

  @impl true
  def handle_event("save", %{"webhook" => params}, socket) do
    events =
      case params["events"] do
        list when is_list(list) -> list
        _ -> []
      end

    attrs = %{
      url: params["url"],
      description: params["description"],
      events: events,
      is_active: params["is_active"] == "true"
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
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
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
        <.webhooks_list webhooks={@webhooks} site={@site} />
      <% end %>
    </div>
    """
  end

  defp webhook_form(assigns) do
    ~H"""
    <.card variant="white">
      <h2 class="text-xl font-semibold mb-4 text-gray-900 dark:text-gray-100">
        <%= if @webhook.id, do: "Edit Webhook", else: "New Webhook" %>
      </h2>

      <.form for={@form} id="webhook-form" phx-submit="save" class="space-y-6">
        <div>
          <.label for="url">Webhook URL</.label>
          <.input field={@form[:url]} type="url" placeholder="https://discord.com/api/webhooks/..." required />
          <p class="text-sm text-gray-500 dark:text-gray-400 mt-1">
            For Discord: Copy the webhook URL from your channel settings
          </p>
        </div>

        <div>
          <.label for="description">Description (optional)</.label>
          <.input field={@form[:description]} type="text" placeholder="e.g., Discord #deployments channel" />
        </div>

        <div>
          <.label>Events</.label>
          <div class="space-y-2 mt-2">
            <label class="flex items-center gap-2">
              <input type="checkbox" name="webhook[events][]" value="deployment.success" 
                checked={@webhook.id && "deployment.success" in @webhook.events}
                class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500" />
              <span class="text-gray-700 dark:text-gray-300">Deployment Successful</span>
            </label>
            <label class="flex items-center gap-2">
              <input type="checkbox" name="webhook[events][]" value="deployment.failed"
                checked={@webhook.id && "deployment.failed" in @webhook.events}
                class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500" />
              <span class="text-gray-700 dark:text-gray-300">Deployment Failed</span>
            </label>
          </div>
        </div>

        <div>
          <label class="flex items-center gap-2">
            <input type="checkbox" name="webhook[is_active]" value="true"
              checked={@webhook.id == nil || @webhook.is_active}
              class="rounded border-gray-300 text-indigo-600 focus:ring-indigo-500" />
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
                    <%= webhook.description || webhook.url %>
                  </h3>
                  <%= if webhook.is_active do %>
                    <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200">
                      Active
                    </span>
                  <% else %>
                    <span class="inline-flex items-center px-2 py-0.5 rounded text-xs font-medium bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300">
                      Inactive
                    </span>
                  <% end %>
                </div>
                
                <p class="text-sm text-gray-600 dark:text-gray-400 font-mono truncate mb-2">
                  {webhook.url}
                </p>

                <div class="flex items-center gap-4 text-sm text-gray-500 dark:text-gray-400">
                  <span>
                    Events: <%= Enum.join(webhook.events, ", ") %>
                  </span>
                  <%= if webhook.last_triggered_at do %>
                    <span>
                      Last triggered: <%= Calendar.strftime(webhook.last_triggered_at, "%Y-%m-%d %H:%M UTC") %>
                    </span>
                  <% end %>
                </div>

                <%= if webhook.last_response_status do %>
                  <div class={"mt-3 p-3 rounded text-sm #{response_status_class(webhook.last_response_status)}"}>
                    <div class="font-medium mb-1">
                      Last Response: <%= webhook.last_response_status %>
                    </div>
                    <%= if webhook.last_response_body do %>
                      <pre class="text-xs overflow-x-auto whitespace-pre-wrap font-mono mt-1 opacity-75"><%= webhook.last_response_body %></pre>
                    <% end %>
                  </div>
                <% end %>
              </div>

              <div class="flex items-center gap-2 ml-4">
                <button phx-click="toggle" phx-value-id={webhook.id} 
                  class="p-2 text-gray-400 hover:text-gray-600 dark:hover:text-gray-200"
                  title={if webhook.is_active, do: "Disable", else: "Enable"}>
                  <%= if webhook.is_active do %>
                    <.icon name="hero-pause-circle" class="w-5 h-5" />
                  <% else %>
                    <.icon name="hero-play-circle" class="w-5 h-5" />
                  <% end %>
                </button>
                <button phx-click="edit" phx-value-id={webhook.id}
                  class="p-2 text-gray-400 hover:text-indigo-600 dark:hover:text-indigo-400"
                  title="Edit">
                  <.icon name="hero-pencil" class="w-5 h-5" />
                </button>
                <button phx-click="delete" phx-value-id={webhook.id}
                  data-confirm="Are you sure you want to delete this webhook?"
                  class="p-2 text-gray-400 hover:text-red-600 dark:hover:text-red-400"
                  title="Delete">
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
```

---

## Phase 6: Router Update

**File:** `lib/upload_web/router.ex` (add to dashboard live_session)

```elixir
live_session :dashboard, on_mount: [{UploadWeb.UserAuth, :mount_current_user}] do
  live "/dashboard", DashboardLive
  live "/sites/:site_id/upload", SiteUploadLive
  live "/sites/:site_id/webhooks", SiteWebhooksLive  # NEW
end
```

---

## Phase 7: Dashboard Link Update

**File:** `lib/upload_web/live/dashboard_live.ex` (modify site card)

Add webhook management link to site cards:

```elixir
<div class="flex flex-col gap-2">
  <.site_url_links site={site} icon="hero-arrow-top-right-on-square" />
  <.link
    navigate={~p"/sites/#{site.id}/upload"}
    class="inline-flex items-center gap-2 text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors"
  >
    <.icon name="hero-arrow-up-tray" class="w-4 h-4" /> Upload
  </.link>
  <%!-- NEW: Webhooks link --%>
  <.link
    navigate={~p"/sites/#{site.id}/webhooks"}
    class="inline-flex items-center gap-2 text-sm font-medium text-gray-700 dark:text-gray-300 hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors"
  >
    <.icon name="hero-bell" class="w-4 h-4" /> Webhooks
  </.link>
</div>
```

Also update the single_site view to include webhook management:

```elixir
<div class="space-y-1">
  <.site_url_links site={@single_site} icon="hero-arrow-top-right-on-square" />
  <.link
    navigate={~p"/sites/#{@single_site.id}/webhooks"}
    class="inline-flex items-center gap-2 text-sm font-medium text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 dark:hover:text-indigo-300 transition-colors"
  >
    <.icon name="hero-bell" class="w-4 h-4" /> Manage Webhooks
  </.link>
</div>
```

---

## Phase 8: Tests

**File:** `test/upload/webhooks_test.exs`

```elixir
defmodule Upload.WebhooksTest do
  use Upload.DataCase

  alias Upload.Webhooks
  alias Upload.Sites.SiteWebhook

  describe "webhooks" do
    import Upload.SitesFixtures
    import Upload.AccountsFixtures

    test "list_site_webhooks/1 returns all webhooks for a site" do
      site = site_fixture()
      webhook = webhook_fixture(site_id: site.id)
      
      assert Webhooks.list_site_webhooks(site.id) == [webhook]
    end

    test "create_webhook/2 with valid data creates a webhook" do
      site = site_fixture()
      
      attrs = %{
        url: "https://discord.com/api/webhooks/test",
        description: "Test webhook",
        events: ["deployment.success"],
        is_active: true
      }
      
      assert {:ok, %SiteWebhook{} = webhook} = Webhooks.create_webhook(site.id, attrs)
      assert webhook.url == attrs.url
      assert webhook.events == ["deployment.success"]
    end

    test "create_webhook/2 with invalid url returns error" do
      site = site_fixture()
      
      attrs = %{url: "not-a-valid-url", events: []}
      assert {:error, %Ecto.Changeset{}} = Webhooks.create_webhook(site.id, attrs)
    end

    test "update_webhook/2 updates the webhook" do
      site = site_fixture()
      webhook = webhook_fixture(site_id: site.id)
      
      assert {:ok, %SiteWebhook{} = webhook} = Webhooks.update_webhook(webhook, %{is_active: false})
      refute webhook.is_active
    end

    test "delete_webhook/1 deletes the webhook" do
      site = site_fixture()
      webhook = webhook_fixture(site_id: site.id)
      
      assert {:ok, %SiteWebhook{}} = Webhooks.delete_webhook(webhook)
      assert Webhooks.list_site_webhooks(site.id) == []
    end
  end
end
```

**File:** `test/support/fixtures/sites_fixtures.ex` (add webhook_fixture)

```elixir
def webhook_fixture(attrs \\ %{}) do
  site_id = attrs[:site_id] || site_fixture().id
  
  {:ok, webhook} =
    attrs
    |> Enum.into(%{
      site_id: site_id,
      url: "https://discord.com/api/webhooks/test/secret",
      description: "Test webhook",
      events: ["deployment.success", "deployment.failed"],
      is_active: true
    })
    |> then(&Upload.Webhooks.create_webhook(site_id, &1))

  webhook
end
```

---

## Summary of Changes

| Phase | Files Modified/Created | Purpose |
|-------|----------------------|---------|
| 1 | `priv/repo/migrations/20260202041001_create_site_webhooks.exs` | Database table |
| 2 | `lib/upload/sites/site_webhook.ex` | Ecto schema |
| 3 | `lib/upload/webhooks.ex` | Business logic & webhook sending |
| 4 | `lib/upload/sites.ex` | Integration with deployment flow |
| 5 | `lib/upload_web/live/site_webhooks_live.ex` | UI for managing webhooks |
| 6 | `lib/upload_web/router.ex` | Route registration |
| 7 | `lib/upload_web/live/dashboard_live.ex` | Navigation links |
| 8 | `test/upload/webhooks_test.exs`, `test/support/fixtures/sites_fixtures.ex` | Tests |

## Key Features
- ✅ Multiple webhooks per site
- ✅ User-managed (not admin)
- ✅ Discord-compatible payloads by default
- ✅ Fire-and-forget (doesn't block deployment)
- ✅ Response logging for debugging (status + body)
- ✅ Enable/disable toggle
- ✅ Event selection (success/failed)

## Next Steps
1. Run `mix ecto.migrate` to create the database table
2. Run `mix precommit` to verify all changes compile
3. Test by:
   - Creating a webhook for a site
   - Deploying to that site
   - Checking the webhook response is logged
