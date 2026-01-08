defmodule Upload.Workers.DeploymentWorker do
  @moduledoc """
  Oban worker for asynchronous deployment of sites to Cloudflare Workers.

  This worker is queued after a file upload and handles the entire deployment
  process, including status updates and error handling.
  """

  use Oban.Worker, queue: :deployments, max_attempts: 3

  require Logger

  alias Upload.Sites
  alias Upload.Sites.Site

  defp cloudflare_deployer do
    Application.get_env(:upload, :cloudflare_deployer, Upload.Deployer.Cloudflare)
  end

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

    case cloudflare_deployer().deploy(site, tarball_path) do
      {:ok, _site} ->
        Sites.mark_deployed(site)
        cleanup_tarball(tarball_path)
        Logger.info(deployment_worker_success: site_id)
        :ok

      {:error, reason} ->
        Logger.error(deployment_worker_failed: site_id, reason: reason)
        Task.start(fn -> Sites.mark_deployment_failed(site, reason) end)
        handle_deployment_error(reason, tarball_path)
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error(invalid_deployment_args: args)
    {:error, :invalid_args}
  end

  # Non-retryable errors - cancel the job and clean up
  defp handle_deployment_error(:missing_cloudflare_config, tarball_path) do
    cleanup_tarball(tarball_path)
    {:cancel, :missing_cloudflare_config}
  end

  defp handle_deployment_error(:no_valid_files, tarball_path) do
    cleanup_tarball(tarball_path)
    {:cancel, :no_valid_files}
  end

  defp handle_deployment_error({:extraction_failed, _} = reason, tarball_path) do
    cleanup_tarball(tarball_path)
    {:cancel, reason}
  end

  defp handle_deployment_error({:path_traversal_detected, _} = reason, tarball_path) do
    cleanup_tarball(tarball_path)
    {:cancel, reason}
  end

  # File/archive errors are non-retryable
  defp handle_deployment_error({:file_stat_failed, _} = reason, tarball_path) do
    cleanup_tarball(tarball_path)
    {:cancel, reason}
  end

  defp handle_deployment_error({:file_too_large, _, _} = reason, tarball_path) do
    cleanup_tarball(tarball_path)
    {:cancel, reason}
  end

  defp handle_deployment_error({:decompressed_too_large, _, _} = reason, tarball_path) do
    cleanup_tarball(tarball_path)
    {:cancel, reason}
  end

  defp handle_deployment_error({:gzip_decompression_failed, _} = reason, tarball_path) do
    cleanup_tarball(tarball_path)
    {:cancel, reason}
  end

  # Cloudflare API errors (4xx/5xx) should not be retried
  defp handle_deployment_error({:api_error, status, _body} = reason, tarball_path)
       when status >= 400 and status < 600 do
    cleanup_tarball(tarball_path)
    {:cancel, reason}
  end

  # Retryable errors - let Oban retry
  defp handle_deployment_error(reason, _tarball_path) do
    {:error, reason}
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
