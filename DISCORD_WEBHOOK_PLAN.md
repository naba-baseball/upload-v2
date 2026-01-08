# Discord Webhook Notifications Implementation Plan

## Overview

Implement Discord webhook notifications to alert users when their site deployments succeed or fail. The deployment service (Cloudflare Workers) completes deployments, our app updates the status, and we send notifications to Discord webhooks configured per site.

## Architecture Decision: Site-Level Webhooks

**Chosen Approach:** Each site has its own Discord webhook URL configured by admins.

**Rationale:**
- Clean separation of concerns (one webhook per site)
- Simple for 3-6 user team
- Easy admin management
- Natural scaling with sites
- Users can organize Discord channels per site

**Alternatives Considered:**
- User-level webhooks: Less granular, harder for multi-site users
- Dedicated notifications table: Over-engineered for current team size

## Database Schema Changes

### Migration: Add `discord_webhook_url` to sites table

```elixir
defmodule Upload.Repo.Migrations.AddDiscordWebhookUrlToSites do
  use Ecto.Migration

  def change do
    alter table(:sites) do
      add :discord_webhook_url, :string
    end
  end
end
```

**Schema Update (`lib/upload/sites/site.ex`):**
```elixir
schema "sites" do
  # ... existing fields ...
  field :discord_webhook_url, :string

  # ... rest of schema ...
end
```

**Changeset Update:**
```elixir
def changeset(site, attrs) do
  site
  |> cast(attrs, [..., :discord_webhook_url])
  |> validate_discord_webhook_url()
end

defp validate_discord_webhook_url(changeset) do
  changeset
  |> validate_format(:discord_webhook_url,
      ~r/^https:\/\/discord\.com\/api\/webhooks\/\d+\/[\w-]+$/,
      message: "must be a valid Discord webhook URL"
    )
end
```

## Core Implementation

### 1. Create Notifications Context

**File: `lib/upload/notifications.ex`**

```elixir
defmodule Upload.Notifications do
  @moduledoc """
  Context for sending notifications (Discord webhooks, etc.)
  """

  alias Upload.Notifications.Discord

  @doc """
  Send a deployment notification for a site.

  ## Options
  - `:status` - :success or :failure (required)
  - `:error` - error message for failures (optional)
  """
  def notify_deployment(site, opts \\ []) do
    if site.discord_webhook_url do
      Discord.send_deployment_notification(site, opts)
    else
      {:ok, :no_webhook_configured}
    end
  end
end
```

**File: `lib/upload/notifications/discord.ex`**

```elixir
defmodule Upload.Notifications.Discord do
  @moduledoc """
  Send notifications to Discord via webhooks.
  """

  require Logger

  @doc """
  Send a deployment notification to Discord.

  ## Examples

      send_deployment_notification(site, status: :success)
      send_deployment_notification(site, status: :failure, error: "Build failed")
  """
  def send_deployment_notification(site, opts) do
    status = Keyword.fetch!(opts, :status)
    error = Keyword.get(opts, :error)

    payload = build_payload(site, status, error)

    case Req.post(site.discord_webhook_url, json: payload) do
      {:ok, %{status: status}} when status in 200..299 ->
        Logger.info("Discord webhook sent successfully",
          site_id: site.id,
          status: status
        )
        {:ok, :sent}

      {:ok, %{status: status, body: body}} ->
        Logger.warning("Discord webhook failed",
          site_id: site.id,
          http_status: status,
          response: body
        )
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.error("Failed to send Discord webhook",
          site_id: site.id,
          error: inspect(reason)
        )
        {:error, reason}
    end
  end

  defp build_payload(site, :success, _error) do
    url = "https://#{site.subdomain}.#{site.base_domain}"
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    %{
      content: "✅ Deployment successful!",
      embeds: [
        %{
          title: site.name,
          url: url,
          color: 5763719, # Green
          fields: [
            %{
              name: "Site URL",
              value: "[#{site.subdomain}.#{site.base_domain}](#{url})",
              inline: true
            },
            %{
              name: "Deployed At",
              value: timestamp,
              inline: true
            }
          ],
          timestamp: timestamp
        }
      ]
    }
  end

  defp build_payload(site, :failure, error) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    error_message = error || "Unknown error"

    # Truncate long error messages for Discord
    truncated_error =
      if String.length(error_message) > 1000 do
        String.slice(error_message, 0, 997) <> "..."
      else
        error_message
      end

    %{
      content: "❌ Deployment failed!",
      embeds: [
        %{
          title: site.name,
          color: 15158332, # Red
          fields: [
            %{
              name: "Subdomain",
              value: "#{site.subdomain}.#{site.base_domain}",
              inline: true
            },
            %{
              name: "Failed At",
              value: timestamp,
              inline: true
            },
            %{
              name: "Error",
              value: "```\n#{truncated_error}\n```",
              inline: false
            }
          ],
          timestamp: timestamp
        }
      ]
    }
  end
end
```

### 2. Integrate with DeploymentWorker

**File: `lib/upload/workers/deployment_worker.ex`**

Add notification calls after status updates:

```elixir
defmodule Upload.Workers.DeploymentWorker do
  use Oban.Worker, queue: :deployments, max_attempts: 3

  alias Upload.{Sites, Notifications}
  # ... existing aliases ...

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"site_id" => site_id, "tarball_path" => tarball_path}}) do
    site = Sites.get_site!(site_id)
    Sites.mark_deploying(site)
    broadcast_deployment_update(site)

    try do
      # ... existing deployment logic ...

      site = Sites.mark_deployed(site)
      broadcast_deployment_update(site)

      # NEW: Send success notification
      Notifications.notify_deployment(site, status: :success)

      :ok
    rescue
      error ->
        formatted_error = Sites.format_deployment_error(error)
        site = Sites.mark_deployment_failed(site, formatted_error)
        broadcast_deployment_update(site)

        # NEW: Send failure notification
        Notifications.notify_deployment(site, status: :failure, error: formatted_error)

        # Determine if error is retryable
        if retryable_error?(error) do
          {:snooze, 30}
        else
          {:cancel, formatted_error}
        end
    after
      File.rm_rf(tarball_path)
    end
  end

  # ... rest of existing code ...
end
```

## UI Updates: Admin Site Management

### Update Admin Sites LiveView

**File: `lib/upload_web/live/admin/sites_live.ex`**

Add Discord webhook URL to form:

```elixir
def render(assigns) do
  ~H"""
  <Layouts.app flash={@flash} current_scope={@current_scope}>
    <!-- ... existing content ... -->

    <.form for={@form} id="site-form" phx-submit="save" phx-change="validate">
      <!-- ... existing fields ... -->

      <.input
        field={@form[:discord_webhook_url]}
        type="text"
        label="Discord Webhook URL (optional)"
        placeholder="https://discord.com/api/webhooks/..."
        phx-debounce="500"
      />

      <p class="text-sm text-gray-600 mt-1 mb-4">
        Get a webhook URL from Discord: Server Settings → Integrations → Webhooks → New Webhook
      </p>

      <!-- ... submit button ... -->
    </.form>
  </Layouts.app>
  """
end

# Update handle_event to include discord_webhook_url
def handle_event("save", %{"site" => site_params}, socket) do
  # ... existing logic ...
  # The discord_webhook_url will be automatically handled by changeset
end
```

### Show Webhook Status in Site List

Add indicator showing if webhook is configured:

```elixir
<div :for={site <- @sites} class="border rounded-lg p-4">
  <div class="flex justify-between items-start">
    <div>
      <h3 class="text-lg font-semibold">{site.name}</h3>
      <p class="text-sm text-gray-600">{site.subdomain}.{site.base_domain}</p>

      <%= if site.discord_webhook_url do %>
        <span class="inline-flex items-center px-2 py-1 text-xs font-medium text-blue-700 bg-blue-100 rounded-full mt-2">
          <.icon name="hero-bell" class="w-3 h-3 mr-1" />
          Discord notifications enabled
        </span>
      <% end %>
    </div>
    <!-- ... rest of site card ... -->
  </div>
</div>
```

## Webhook Configuration Testing

### Add Test Webhook Button (Optional Nice-to-Have)

Allow admins to test Discord webhooks:

```elixir
def handle_event("test_webhook", %{"site_id" => site_id}, socket) do
  site = Sites.get_site!(site_id)

  case Notifications.Discord.send_deployment_notification(site, status: :success) do
    {:ok, :sent} ->
      {:noreply, put_flash(socket, :info, "Test notification sent to Discord!")}

    {:error, _reason} ->
      {:noreply, put_flash(socket, :error, "Failed to send test notification. Check webhook URL.")}
  end
end
```

## Error Handling & Edge Cases

### Webhook Failures

- Log all webhook failures with structured logging
- Do NOT retry webhook notifications (they're best-effort)
- Do NOT block deployment status updates if webhook fails
- Webhook failures should be logged but not affect deployment outcome

### Validation

- Validate Discord webhook URL format
- Allow empty/nil webhook URL (optional feature)
- Truncate error messages to fit Discord's 2000 char limit per field

### Security

- Store webhook URLs as plain text (they're not secrets per Discord docs)
- Webhook URLs contain unique tokens that provide security
- Only admins can configure webhook URLs
- Rate limiting handled by Discord (30 requests/60s per webhook)

## Testing Strategy

### Unit Tests

**File: `test/upload/notifications/discord_test.exs`**

```elixir
defmodule Upload.Notifications.DiscordTest do
  use Upload.DataCase

  alias Upload.Notifications.Discord

  describe "build_payload/3" do
    test "creates success payload with correct structure" do
      site = %Upload.Sites.Site{
        name: "Test Site",
        subdomain: "test",
        base_domain: "nabaleague.com"
      }

      payload = Discord.build_payload(site, :success, nil)

      assert payload.content == "✅ Deployment successful!"
      assert [embed] = payload.embeds
      assert embed.title == "Test Site"
      assert embed.color == 5763719
      assert embed.url == "https://test.nabaleague.com"
    end

    test "creates failure payload with error message" do
      site = %Upload.Sites.Site{
        name: "Test Site",
        subdomain: "test",
        base_domain: "nabaleague.com"
      }

      payload = Discord.build_payload(site, :failure, "Build failed")

      assert payload.content == "❌ Deployment failed!"
      assert [embed] = payload.embeds
      assert embed.color == 15158332

      error_field = Enum.find(embed.fields, fn f -> f.name == "Error" end)
      assert error_field.value =~ "Build failed"
    end

    test "truncates long error messages" do
      site = %Upload.Sites.Site{
        name: "Test Site",
        subdomain: "test",
        base_domain: "nabaleague.com"
      }

      long_error = String.duplicate("error ", 300)
      payload = Discord.build_payload(site, :failure, long_error)

      error_field = Enum.find(hd(payload.embeds).fields, fn f -> f.name == "Error" end)
      assert String.length(error_field.value) <= 1010 # 1000 chars + markup
      assert String.ends_with?(error_field.value, "...\n```")
    end
  end
end
```

### Integration Tests

**File: `test/upload/notifications_test.exs`**

Mock Req library to test webhook sending without hitting real Discord API.

### LiveView Tests

**File: `test/upload_web/live/admin/sites_live_test.exs`**

Test that Discord webhook URL field appears and validates correctly in admin UI.

## Implementation Checklist

1. **Database Migration**
   - [ ] Generate migration: `mix ecto.gen.migration add_discord_webhook_url_to_sites`
   - [ ] Run migration: `mix ecto.migrate`
   - [ ] Update Site schema with new field
   - [ ] Add changeset validation for webhook URL format

2. **Core Notification Logic**
   - [ ] Create `lib/upload/notifications.ex` context
   - [ ] Create `lib/upload/notifications/discord.ex` module
   - [ ] Implement `send_deployment_notification/2`
   - [ ] Implement success payload builder
   - [ ] Implement failure payload builder
   - [ ] Add error truncation for long messages

3. **Integration with Deployment**
   - [ ] Update `DeploymentWorker` to call notifications on success
   - [ ] Update `DeploymentWorker` to call notifications on failure
   - [ ] Ensure notifications don't block deployment status updates
   - [ ] Add structured logging for notification attempts

4. **Admin UI Updates**
   - [ ] Add Discord webhook URL input to admin sites form
   - [ ] Add validation and help text for webhook URL
   - [ ] Add visual indicator for sites with webhooks configured
   - [ ] (Optional) Add test webhook button

5. **Testing**
   - [ ] Write unit tests for Discord module
   - [ ] Write integration tests for Notifications context
   - [ ] Write LiveView tests for admin UI
   - [ ] Manual testing with real Discord webhooks

6. **Documentation & Polish**
   - [ ] Update README with webhook feature
   - [ ] Add comments explaining webhook flow
   - [ ] Run `mix precommit` to catch any issues
   - [ ] Test end-to-end with real deployments

## Timeline & Dependencies

**Prerequisites:**
- None (greenfield feature)

**Dependencies:**
- Req library (already included)
- Phoenix PubSub (already configured)
- Existing deployment flow

**Estimated Complexity:** Low-Medium

**Risk Areas:**
- Discord API rate limits (30 req/min per webhook)
- Webhook URL format validation edge cases
- Long error messages exceeding Discord limits

## Future Enhancements (Out of Scope)

- Customized Discord messages (mentions, custom formatting)
- Multiple webhooks per site
- Other notification channels (Slack, email, etc.)
- Webhook delivery retry logic
- Notification preferences (success-only, failure-only)
- Webhook activity logs/history

## References

- [Discord Webhooks Documentation](https://discord.com/developers/docs/resources/webhook)
- [Discord Webhook Limits](https://discord.com/developers/docs/topics/rate-limits)
- [Req Library Documentation](https://hexdocs.pm/req/)
- [Phoenix PubSub Documentation](https://hexdocs.pm/phoenix_pubsub/)

---

**Author:** Claude
**Date:** 2026-01-08
**Status:** Ready for Implementation
