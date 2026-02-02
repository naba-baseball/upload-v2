defmodule Upload.Sites.SiteWebhook do
  use Ecto.Schema
  import Ecto.Changeset

  @events ~w(deployment.success deployment.failed)

  schema "site_webhooks" do
    field :url, :string
    field :description, :string
    field :events, {:array, :string}, default: []
    field :role_mention, :string
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
    |> cast(attrs, [:url, :description, :events, :role_mention, :is_active])
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
