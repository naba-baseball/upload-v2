defmodule Upload.Deployer.Cloudflare do
  @moduledoc """
  Handles deployment of static assets to Cloudflare Workers.

  Deployment flow:
  1. Extract .tar.gz to temporary directory
  2. Build asset manifest with file hashes
  3. Submit manifest to get upload JWT
  4. Upload asset files (batched, base64-encoded)
  5. Get completion JWT after all uploads
  6. Deploy worker with assets JWT
  7. Configure custom domain (if first deploy)
  8. Clean up temporary files
  """

  require Logger

  alias Upload.Deployer.Cloudflare.{Client, Manifest, WorkerTemplate}
  alias Upload.Sites.Site

  @batch_size 100

  @doc """
  Deploys a site from a tarball to Cloudflare Workers.

  Takes a site and the path to the uploaded .tar.gz file.
  Returns `{:ok, site}` on success or `{:error, reason}` on failure.
  """
  def deploy(%Site{} = site, tarball_path) do
    worker_name = Site.worker_name(site)

    Logger.info(
      deploying_site: site.id,
      subdomain: site.subdomain,
      worker_name: worker_name,
      tarball_path: tarball_path
    )

    with {:ok, extract_dir} <- extract_tarball(tarball_path),
         {:ok, manifest} <- build_manifest(extract_dir),
         {:ok, %{jwt: upload_jwt, buckets: buckets}} <-
           Client.submit_manifest(worker_name, manifest),
         :ok <- upload_assets(extract_dir, manifest, buckets, upload_jwt),
         {:ok, completion_jwt} <- Client.get_completion_jwt(upload_jwt),
         {:ok, _} <- deploy_worker(worker_name, completion_jwt),
         :ok <- ensure_custom_domain(site, worker_name),
         :ok <- cleanup(extract_dir) do
      Logger.info(deployment_success: site.id, worker_name: worker_name)
      {:ok, site}
    else
      {:error, reason} = error ->
        Logger.error(deployment_failed: site.id, reason: reason)
        error
    end
  end

  @doc """
  Extracts a tarball to a temporary directory.

  Returns `{:ok, extract_dir}` or `{:error, reason}`.
  """
  def extract_tarball(tarball_path) do
    extract_dir = Path.join(System.tmp_dir!(), "extract_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(extract_dir)

    case System.cmd("tar", ["-xzf", tarball_path, "-C", extract_dir],
           stderr_to_stdout: true,
           env: [{"LC_ALL", "en_US.UTF-8"}, {"LANG", "en_US.UTF-8"}]
         ) do
      {_, 0} ->
        # Validate no path traversal in extracted files
        case validate_extracted_paths(extract_dir) do
          :ok -> {:ok, extract_dir}
          {:error, _} = error -> error
        end

      {output, code} ->
        Logger.error(tar_extraction_failed: tarball_path, exit_code: code, output: output)
        {:error, {:extraction_failed, output}}
    end
  end

  @doc """
  Builds an asset manifest from the extracted directory.
  """
  def build_manifest(extract_dir) do
    case Manifest.build(extract_dir) do
      %{manifest: manifest} when map_size(manifest) > 0 ->
        {:ok, manifest}

      %{manifest: manifest} when map_size(manifest) == 0 ->
        {:error, :no_valid_files}
    end
  end

  @doc """
  Uploads assets that Cloudflare doesn't already have.

  The `buckets` list contains hashes of files that need to be uploaded.
  Files are uploaded in batches to avoid overwhelming the API.
  """
  def upload_assets(extract_dir, manifest, buckets, upload_jwt) do
    # Build a set of hashes that need uploading
    needed_hashes = MapSet.new(List.flatten(buckets))

    # Find files that need to be uploaded
    files_to_upload =
      manifest
      |> Enum.filter(fn {_path, %{hash: hash}} -> MapSet.member?(needed_hashes, hash) end)
      |> Enum.map(fn {path, %{hash: hash}} ->
        # path is like "/index.html", need to convert to file path
        file_path = Path.join(extract_dir, String.trim_leading(path, "/"))
        content = File.read!(file_path)
        %{hash: hash, content: content}
      end)

    # Upload in batches
    files_to_upload
    |> Enum.chunk_every(@batch_size)
    |> Enum.reduce_while(:ok, fn batch, :ok ->
      case Client.upload_assets(batch, upload_jwt) do
        {:ok, _} -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  @doc """
  Deploys the worker script with the assets.
  """
  def deploy_worker(worker_name, completion_jwt) do
    worker_js = WorkerTemplate.worker_js()
    metadata = WorkerTemplate.metadata(completion_jwt)

    Client.deploy_worker(worker_name, worker_js, metadata)
  end

  @doc """
  Ensures the custom domain is configured for the worker.
  """
  def ensure_custom_domain(%Site{} = site, worker_name) do
    hostname = Site.full_domain(site)

    case Client.create_custom_domain(worker_name, hostname) do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  @doc """
  Cleans up temporary extraction directory.
  """
  def cleanup(extract_dir) do
    File.rm_rf!(extract_dir)
    :ok
  end

  # Private functions

  defp validate_extracted_paths(extract_dir) do
    extract_dir
    |> Manifest.list_files_recursive()
    |> Enum.find(fn path ->
      relative = Path.relative_to(path, extract_dir)
      String.contains?(relative, "..") or Path.type(relative) == :absolute
    end)
    |> case do
      nil -> :ok
      bad_path -> {:error, {:path_traversal_detected, bad_path}}
    end
  end
end
