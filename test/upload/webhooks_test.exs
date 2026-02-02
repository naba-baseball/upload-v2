defmodule Upload.WebhooksTest do
  use Upload.DataCase

  alias Upload.Webhooks
  alias Upload.Sites.SiteWebhook

  describe "webhooks" do
    import Upload.SitesFixtures

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

      assert {:ok, %SiteWebhook{} = webhook} =
               Webhooks.update_webhook(webhook, %{is_active: false})

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
