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
  def trigger_webhooks(%Site{} = site, event)
      when event in ["deployment.success", "deployment.failed"] do
    site.id
    |> list_active_webhooks_for_event(event)
    |> Enum.each(fn webhook ->
      Task.start(fn ->
        send_webhook(webhook, site, event)
      end)
    end)
  end

  @doc """
  Sends a test webhook to verify the webhook works.
  Returns {:ok, status, body} on success or {:error, reason} on failure.
  """
  def test_webhook(%SiteWebhook{} = webhook, %Site{} = site) do
    payload = build_test_payload(webhook, site)

    case Req.post(webhook.url,
           json: payload,
           receive_timeout: 30_000,
           retry: :never
         ) do
      {:ok, %{status: status} = response} ->
        {:ok, status, response.body}

      {:error, reason} ->
        {:error, inspect(reason)}
    end
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
      last_triggered_at: DateTime.utc_now() |> DateTime.truncate(:second)
    )
    |> Repo.update()
  end

  defp build_payload(%SiteWebhook{} = webhook, %Site{} = site, event) do
    content =
      format_role_mention(webhook.role_mention) <> " **#{Site.format_site_url(site)}** has #{event_action(event)}"

    %{
      content: content,
      embeds: [
        %{
          title: "Deployment #{event_result(event)}",
          description: "**#{site.name}** has #{event_action(event)}",
          color: event_color(event),
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          fields: [
            %{name: "Site", value: site.name, inline: true},
          ],
          url: Site.format_site_url(site)
        }
      ]
    }
  end

  defp format_role_mention(nil), do: nil
  defp format_role_mention(""), do: nil
  defp format_role_mention(role_mention), do: role_mention

  defp build_test_payload(%SiteWebhook{} = webhook, %Site{} = site) do
    content = format_role_mention(webhook.role_mention)

    %{
      content: content,
      embeds: [
        %{
          title: "Test Webhook",
          description: "This is a test message for **#{site.name}**",
          color: 0x3498DB,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
          fields: [
            %{name: "Site", value: site.name, inline: true},
            %{name: "Subdomain", value: site.subdomain, inline: true}
          ]
        }
      ]
    }
  end

  defp event_result("deployment.success"), do: "Successful"
  defp event_result("deployment.failed"), do: "Failed"

  defp event_action("deployment.success"), do: "updated"
  defp event_action("deployment.failed"), do: "failed to update"

  # Green
  defp event_color("deployment.success"), do: 0x00FF00
  # Red
  defp event_color("deployment.failed"), do: 0xFF0000
end
