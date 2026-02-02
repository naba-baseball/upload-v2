defmodule UploadWeb.Admin.SitesLive do
  use UploadWeb, :live_view
  import UploadWeb.AdminComponents
  import UploadWeb.UploadComponents

  alias Upload.Sites
  alias Upload.Sites.Site

  @impl true
  def mount(_params, _session, socket) do
    sites = Sites.list_sites()
    base_domain = Application.get_env(:upload, :base_domain)

    {:ok,
     socket
     |> assign(:page_title, "Manage Sites")
     |> assign(:editing_site_id, nil)
     |> assign(:site_form, nil)
     |> assign(:sites, sites)
     |> assign(:base_domain, base_domain)
     |> stream(:sites, sites)}
  end

  @impl true
  def handle_event("new_site", _params, socket) do
    site_form = to_form(Site.changeset(%Site{}, %{}))

    {:noreply,
     socket
     |> assign(:editing_site_id, :new)
     |> assign(:site_form, site_form)}
  end

  @impl true
  def handle_event("edit_site", %{"site-id" => site_id}, socket) do
    site_id = String.to_integer(site_id)
    site = Sites.get_site!(site_id)

    site_form = to_form(Site.changeset(site, %{}))

    {:noreply,
     socket
     |> assign(:editing_site_id, site_id)
     |> assign(:site_form, site_form)
     |> stream_insert(:sites, site)}
  end

  @impl true
  def handle_event("cancel_site_edit", _params, socket) do
    socket =
      case socket.assigns.editing_site_id do
        :new ->
          socket

        site_id when is_integer(site_id) ->
          site = Sites.get_site!(site_id)
          stream_insert(socket, :sites, site)

        _ ->
          socket
      end

    {:noreply,
     socket
     |> assign(:editing_site_id, nil)
     |> assign(:site_form, nil)}
  end

  @impl true
  def handle_event("save_site", %{"site" => site_params}, socket) do
    case socket.assigns.editing_site_id do
      :new ->
        case Sites.create_site(site_params) do
          {:ok, site} ->
            sites = Sites.list_sites()

            {:noreply,
             socket
             |> put_flash(:info, "Site created successfully")
             |> assign(:editing_site_id, nil)
             |> assign(:site_form, nil)
             |> assign(:sites, sites)
             |> stream_insert(:sites, site, at: 0)}

          {:error, changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to create site")
             |> assign(:site_form, to_form(changeset))}
        end

      site_id when is_integer(site_id) ->
        site = Sites.get_site!(site_id)

        case Sites.update_site(site, site_params) do
          {:ok, updated_site} ->
            sites = Sites.list_sites()

            {:noreply,
             socket
             |> put_flash(:info, "Site updated successfully")
             |> assign(:editing_site_id, nil)
             |> assign(:site_form, nil)
             |> assign(:sites, sites)
             |> stream_insert(:sites, updated_site)}

          {:error, changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to update site")
             |> assign(:site_form, to_form(changeset))}
        end
    end
  end

  @impl true
  def handle_event("delete_site", %{"site-id" => site_id}, socket) do
    site_id = String.to_integer(site_id)
    site = Sites.get_site!(site_id)

    case Sites.delete_site(site) do
      {:ok, _site} ->
        sites = Sites.list_sites()

        {:noreply,
         socket
         |> put_flash(:info, "Site deleted successfully")
         |> assign(:sites, sites)
         |> stream_delete(:sites, site)}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to delete site")}
    end
  end

  @impl true
  def handle_event("validate_site", %{"site" => site_params}, socket) do
    changeset =
      case socket.assigns.editing_site_id do
        :new ->
          %Site{}
          |> Site.changeset(site_params)
          |> Map.put(:action, :validate)

        site_id when is_integer(site_id) ->
          site = Sites.get_site!(site_id)

          site
          |> Site.changeset(site_params)
          |> Map.put(:action, :validate)
      end

    {:noreply, assign(socket, :site_form, to_form(changeset))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.admin_layout
      current_user={@current_user}
      flash={@flash}
      page_title="Sites"
      active_tab="sites"
    >
      <:actions>
        <.button phx-click="new_site">
          + New Site
        </.button>
      </:actions>

      <div id="sites-list" phx-update="stream" class="space-y-4">
        <.card :for={{id, site} <- @streams.sites} id={id}>
          <%= if @editing_site_id == site.id do %>
            <.site_form
              form={@site_form}
              id={"edit-site-form-#{site.id}"}
              submit_label="Save"
              base_domain={@base_domain}
            />
          <% else %>
            <.site_display site={site} base_domain={@base_domain} />
          <% end %>
        </.card>
      </div>

      <%= if @editing_site_id == :new do %>
        <.card class="mt-4">
          <h3 class="font-semibold mb-4 text-gray-900 dark:text-gray-100">New Site</h3>
          <.site_form
            form={@site_form}
            id="new-site-form"
            submit_label="Create Site"
            base_domain={@base_domain}
          />
        </.card>
      <% end %>
    </.admin_layout>
    """
  end

  defp site_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id={@id}
      phx-submit="save_site"
      phx-change="validate_site"
    >
      <div class="space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <.input field={@form[:name]} type="text" label="Site Name" required />
          <.input field={@form[:subdomain]} type="text" label="Subdomain" required />
        </div>
        <div>
          <.input
            field={@form[:routing_mode]}
            type="select"
            label="Routing Mode"
            options={[
              {"Subdomain only (default)", "subdomain"},
              {"Subpath only", "subpath"},
              {"Both subdomain and subpath", "both"}
            ]}
          />
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
            Controls how users can access this site
          </p>
        </div>
        <div>
          <.input
            field={@form[:format_version]}
            type="select"
            label="OOTP Export Format"
            options={[
              {"OOTP 23+ (news/html structure)", "ootp23"}
            ]}
          />
          <p class="text-xs text-gray-500 dark:text-gray-400 mt-1">
            The format of the exported website files from OOTP
          </p>
        </div>
        <div class="text-sm text-gray-600 dark:text-gray-300 space-y-1">
          <p class="font-medium">Access URLs:</p>
          <p>
            <span class="text-gray-500 dark:text-gray-400">Subdomain:</span>
            <.link
              href={"#{Site.url_scheme()}#{subdomain_preview(@form[:subdomain].value, @base_domain)}"}
              target="_blank"
              class="font-mono hover:text-accent hover:underline"
            >
              {Site.url_scheme()}{subdomain_preview(@form[:subdomain].value, @base_domain)}
            </.link>
          </p>
          <p>
            <span class="text-secondary">Subpath:</span>
            <.link
              href={"#{Site.url_scheme()}#{@base_domain}/sites/#{subdomain_value(@form[:subdomain].value)}"}
              target="_blank"
              class="font-mono hover:text-accent hover:underline"
            >
              {Site.url_scheme()}{@base_domain}/sites/{subdomain_value(@form[:subdomain].value)}
            </.link>
          </p>
        </div>
        <div class="flex gap-2">
          <.button variant="success" type="submit">
            {@submit_label}
          </.button>
          <.button variant="secondary" type="button" phx-click="cancel_site_edit">
            Cancel
          </.button>
        </div>
      </div>
    </.form>
    """
  end

  defp site_display(assigns) do
    ~H"""
    <div class="flex justify-between items-center">
      <div>
        <div class="flex items-center gap-3 mb-1">
          <h3 class="font-semibold text-lg text-gray-900 dark:text-gray-100">
            {@site.name}
          </h3>
          <.deployment_status
            status={@site.deployment_status}
            last_deployed_at={@site.last_deployed_at}
          />
        </div>
        <div class="text-sm space-y-1">
          <.site_url_links site={@site} display="full_url" />
          <p class="text-xs text-gray-500 dark:text-gray-400">
            Mode: {@site.routing_mode} | Format: {@site.format_version}
          </p>
        </div>
      </div>
      <div class="flex gap-2">
        <.button variant="primary" size="sm" phx-click="edit_site" phx-value-site-id={@site.id}>
          Edit
        </.button>
        <.button
          variant="danger"
          size="sm"
          phx-click="delete_site"
          phx-value-site-id={@site.id}
          data-confirm="Are you sure you want to delete this site?"
        >
          Delete
        </.button>
      </div>
    </div>

    <%= if @site.deployment_status == "failed" && @site.last_deployment_error do %>
      <div class="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
        <div class="text-xs text-red-600 dark:text-red-400 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded px-3 py-2">
          <p class="font-semibold mb-1">Deployment Error:</p>
          <p class="font-mono whitespace-pre-wrap break-all">{@site.last_deployment_error}</p>
        </div>
      </div>
    <% end %>
    """
  end

  defp subdomain_preview(nil, base_domain), do: "subdomain.#{base_domain}"
  defp subdomain_preview("", base_domain), do: "subdomain.#{base_domain}"
  defp subdomain_preview(subdomain, base_domain), do: "#{subdomain}.#{base_domain}"

  defp subdomain_value(nil), do: "subdomain"
  defp subdomain_value(""), do: "subdomain"
  defp subdomain_value(subdomain), do: subdomain
end
