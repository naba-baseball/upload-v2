defmodule Upload.Workers.DeploymentWorker do
  @moduledoc """
  Oban worker for asynchronous deployment of sites to local storage.

  This worker is queued after a file upload and handles the entire deployment
  process by extracting the tarball to priv/static/sites/{subdomain}/ and
  validating the extracted files.
  """

  use Oban.Worker, queue: :deployments, max_attempts: 1

  require Logger

  alias Upload.Sites
  alias Upload.Deployer.TarExtractor

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"site_id" => site_id, "tarball_path" => tarball_path}}) do
    Logger.info(deployment_worker_started: site_id, tarball_path: tarball_path)

    site = Sites.get_site!(site_id)

    # Mark as deploying
    {:ok, site} = Sites.mark_deploying(site)

    case deploy_to_local(site, tarball_path) do
      :ok ->
        Sites.mark_deployed(site)
        cleanup_tarball(tarball_path)
        Logger.info(deployment_worker_success: site_id)
        :ok

      {:error, reason} ->
        Logger.error(deployment_worker_failed: site_id, reason: reason)
        Sites.mark_deployment_failed(site, reason)
        cleanup_tarball(tarball_path)
        {:cancel, reason}
    end
  end

  def perform(%Oban.Job{args: args}) do
    Logger.error(invalid_deployment_args: args)
    {:error, :invalid_args}
  end

  defp deploy_to_local(site, tarball_path) do
    # Determine target directory for this site
    site_dir = Path.join([:code.priv_dir(:upload), "static", "sites", site.subdomain])

    # Clean up existing site directory before extraction
    if File.exists?(site_dir) do
      Logger.info(cleaning_existing_site_directory: site_dir)
      File.rm_rf!(site_dir)
    end

    # Extract tarball to site directory
    case TarExtractor.extract(tarball_path, site_dir) do
      {:ok, _extract_dir} ->
        # Validate at least one HTML file exists
        case validate_html_files(site_dir) do
          :ok ->
            :ok

          {:error, _reason} = error ->
            # Clean up extraction since validation failed
            File.rm_rf(site_dir)
            error
        end

      {:error, _reason} = error ->
        # Clean up partial extraction on failure
        File.rm_rf(site_dir)
        error
    end
  end

  defp validate_html_files(site_dir) do
    # Recursively find all HTML files
    html_files =
      site_dir
      |> Path.join("**/*.{html,htm}")
      |> Path.wildcard()

    if Enum.empty?(html_files) do
      {:error, :no_html_files}
    else
      Logger.info(html_files_found: length(html_files))
      :ok
    end
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
