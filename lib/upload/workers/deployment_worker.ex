defmodule Upload.Workers.DeploymentWorker do
  @moduledoc """
  Oban worker for asynchronous deployment of sites to Cloudflare Workers.

  This worker is queued after a file upload and handles the entire deployment
  process, including status updates and error handling.
  """

  use Oban.Worker, queue: :deployments, max_attempts: 3

  require Logger

  alias Upload.Deployer.Cloudflare
  alias Upload.Sites
  alias Upload.Sites.Site

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"site_id" => site_id, "tarball_path" => tarball_path}}) do
    Logger.info(deployment_worker_started: site_id, tarball_path: tarball_path)

    site = Sites.get_site!(site_id)

    # Mark as deploying
    {:ok, site} = Sites.mark_deploying(site)

    # Ensure worker name is set
    worker_name = Site.worker_name(site)

    if is_nil(site.cloudflare_worker_name) do
      Sites.set_worker_name(site, worker_name)
    end

    case Cloudflare.deploy(site, tarball_path) do
      {:ok, _site} ->
        Sites.mark_deployed(site)
        cleanup_tarball(tarball_path)
        Logger.info(deployment_worker_success: site_id)
        :ok

      {:error, reason} ->
        Sites.mark_deployment_failed(site, reason)
        Logger.error(deployment_worker_failed: site_id, reason: reason)
        {:error, reason}
    end
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    Logger.error(invalid_deployment_args: args)
    {:error, :invalid_args}
  end

  defp cleanup_tarball(tarball_path) do
    case File.rm(tarball_path) do
      :ok ->
        Logger.info(tarball_cleaned_up: tarball_path)

      {:error, reason} ->
        Logger.warning(tarball_cleanup_failed: tarball_path, reason: reason)
    end
  end
end
