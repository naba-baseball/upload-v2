defmodule Upload.Deployer.Cloudflare.Client do
  @moduledoc """
  HTTP client for Cloudflare Workers API.

  Handles all API communication including:
  - Asset upload sessions (manifest submission)
  - Asset file uploads (batched, base64-encoded)
  - Worker script deployment
  - Custom domain configuration
  """

  require Logger

  @base_url "https://api.cloudflare.com/client/v4"

  @doc """
  Submits an asset manifest to start an upload session.

  Returns `{:ok, %{jwt: upload_jwt, buckets: buckets}}` where:
  - `jwt` is the token for uploading assets
  - `buckets` is a list of file hashes that need to be uploaded (Cloudflare may already have some)
  """
  def submit_manifest(script_name, manifest) do
    url =
      "#{@base_url}/accounts/#{account_id()}/workers/scripts/#{script_name}/assets-upload-session"

    case Req.post(url, json: %{manifest: manifest}, headers: auth_headers()) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        result = body["result"] || %{}
        {:ok, %{jwt: result["jwt"], buckets: result["buckets"] || []}}

      {:ok, %{status: status, body: body}} ->
        Logger.error(cloudflare_error: "submit_manifest", status: status, body: body)
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error(cloudflare_error: "submit_manifest", reason: reason)
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Uploads asset files to Cloudflare.

  Files should be a list of maps with `:hash` and `:content` keys.
  Files are uploaded base64-encoded in batches.
  """
  def upload_assets(files, upload_jwt) do
    url = "#{@base_url}/accounts/#{account_id()}/workers/assets/upload?base64=true"

    multipart =
      Enum.map(files, fn %{hash: hash, content: content} ->
        {:file,
         content: Base.encode64(content), filename: hash, content_type: "application/octet-stream"}
      end)

    headers = [{"authorization", "Bearer #{upload_jwt}"}]

    case Req.post(url, form_multipart: multipart, headers: headers) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error(cloudflare_error: "upload_assets", status: status, body: body)
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error(cloudflare_error: "upload_assets", reason: reason)
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Gets a completion JWT after all assets are uploaded.

  This JWT is used when deploying the worker to bind the assets.
  """
  def get_completion_jwt(upload_jwt) do
    url = "#{@base_url}/accounts/#{account_id()}/workers/assets/upload"
    headers = [{"authorization", "Bearer #{upload_jwt}"}]

    case Req.get(url, headers: headers) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        result = body["result"] || %{}
        {:ok, result["jwt"]}

      {:ok, %{status: status, body: body}} ->
        Logger.error(cloudflare_error: "get_completion_jwt", status: status, body: body)
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error(cloudflare_error: "get_completion_jwt", reason: reason)
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Deploys a worker script with the given assets.

  Uses multipart form upload to send the worker code and metadata.
  """
  def deploy_worker(script_name, worker_js, metadata) do
    url = "#{@base_url}/accounts/#{account_id()}/workers/scripts/#{script_name}"

    multipart = [
      {:file,
       content: worker_js, filename: "worker.js", content_type: "application/javascript+module"},
      {:file,
       content: Jason.encode!(metadata),
       filename: "metadata.json",
       content_type: "application/json"}
    ]

    case Req.put(url, form_multipart: multipart, headers: auth_headers()) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error(cloudflare_error: "deploy_worker", status: status, body: body)
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error(cloudflare_error: "deploy_worker", reason: reason)
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Configures a custom domain for the worker.

  This sets up routing from the custom domain (e.g., example.nabaleague.com)
  to the worker script.
  """
  def create_custom_domain(script_name, hostname) do
    url = "#{@base_url}/accounts/#{account_id()}/workers/domains"

    body = %{
      hostname: hostname,
      service: script_name,
      environment: "production"
    }

    case Req.put(url, json: body, headers: auth_headers()) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{status: 409, body: body}} ->
        # Domain already exists - this is okay for updates
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error(cloudflare_error: "create_custom_domain", status: status, body: body)
        {:error, {:api_error, status, body}}

      {:error, reason} ->
        Logger.error(cloudflare_error: "create_custom_domain", reason: reason)
        {:error, {:request_failed, reason}}
    end
  end

  @doc """
  Checks if a worker script exists.
  """
  def worker_exists?(script_name) do
    url = "#{@base_url}/accounts/#{account_id()}/workers/scripts/#{script_name}"

    case Req.get(url, headers: auth_headers()) do
      {:ok, %{status: 200}} -> true
      _ -> false
    end
  end

  # Private functions

  defp account_id do
    config()[:account_id] || raise "CLOUDFLARE_ACCOUNT_ID not configured"
  end

  defp api_token do
    config()[:api_token] || raise "CLOUDFLARE_API_TOKEN not configured"
  end

  defp config do
    Application.get_env(:upload, :cloudflare, [])
  end

  defp auth_headers do
    [
      {"authorization", "Bearer #{api_token()}"},
      {"content-type", "application/json"}
    ]
  end
end
