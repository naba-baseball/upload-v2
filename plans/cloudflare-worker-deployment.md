# Cloudflare Worker Deployment Feature

## Executive Summary

Deploy uploaded static assets to Cloudflare Workers using Worker Static Assets. Each site gets its own Worker, with the subdomain configured as a Custom Domain. The Worker is minimal - it just serves static assets with no custom logic.

## Current State

- Files upload as `.tar.gz` to `/tmp/{subdomain}_{uuid}.tar.gz`
- No deployment logic exists
- Sites have `subdomain` and `base_domain` fields (e.g., `example.nabaleague.com`)
- `Req` HTTP client already included
- No background job processing yet

## Key Design Decisions

### 1. Worker Creation: Manual vs Automated

| Approach | Pros | Cons |
|----------|------|------|
| **Manual setup** | Simpler, no API complexity for project creation | Requires admin to create each worker in Cloudflare dashboard first |
| **Automated** | Fully hands-off deployment | More API complexity, need to handle custom domain setup |

**Recommendation**: Start with **semi-automated** - the app creates workers and uploads assets via API, but assumes the base domain (`nabaleague.com`) is already configured in Cloudflare with proper zone access. Workers can auto-create on first deploy.

### 2. Worker Architecture

Each site gets a **static-only worker** with this minimal structure:

```javascript
// worker.js - serves only static assets
export default {
  async fetch(request, env) {
    return env.ASSETS.fetch(request);
  }
};
```

The `wrangler.toml` equivalent configuration:
```toml
[assets]
directory = "./dist"
not_found_handling = "single-page-application"  # or "404-page"
```

---

## Implementation Plan

### Phase 1: Database & Configuration

#### 1.1 Add Cloudflare configuration to Sites

New migration to add deployment fields to `sites`:
```elixir
alter table(:sites) do
  add :cloudflare_worker_name, :string  # e.g., "upload-site-example"
  add :deployment_status, :string, default: "pending"  # pending, deploying, deployed, failed
  add :last_deployed_at, :utc_datetime
  add :last_deployment_error, :text
end
```

#### 1.2 Add global Cloudflare credentials

Store in application config (not per-site, since all sites deploy to same account):
```elixir
# config/runtime.exs
config :upload, :cloudflare,
  account_id: System.get_env("CLOUDFLARE_ACCOUNT_ID"),
  api_token: System.get_env("CLOUDFLARE_API_TOKEN"),
  zone_id: System.get_env("CLOUDFLARE_ZONE_ID")  # for nabaleague.com
```

### Phase 2: Core Deployment Module

#### 2.1 Create `Upload.Deployer.Cloudflare` module

```elixir
defmodule Upload.Deployer.Cloudflare do
  @moduledoc """
  Handles deployment of static assets to Cloudflare Workers.

  Deployment flow:
  1. Extract .tar.gz to temporary directory
  2. Submit asset manifest to get upload JWT
  3. Upload asset files (batched, base64-encoded)
  4. Deploy worker with assets JWT
  5. Configure custom domain (if first deploy)
  """

  def deploy(site, tarball_path) do
    with {:ok, extract_dir} <- extract_tarball(tarball_path),
         {:ok, manifest} <- build_manifest(extract_dir),
         {:ok, upload_jwt, buckets} <- submit_manifest(site, manifest),
         :ok <- upload_assets(extract_dir, buckets, upload_jwt),
         {:ok, completion_jwt} <- get_completion_jwt(upload_jwt),
         {:ok, _} <- deploy_worker(site, completion_jwt),
         :ok <- ensure_custom_domain(site) do
      {:ok, site}
    end
  end
end
```

#### 2.2 Key functions breakdown

```elixir
# Extract tarball
defp extract_tarball(path) do
  extract_dir = Path.join(System.tmp_dir!(), "extract_#{:erlang.unique_integer()}")
  File.mkdir_p!(extract_dir)

  case System.cmd("tar", ["-xzf", path, "-C", extract_dir]) do
    {_, 0} -> {:ok, extract_dir}
    {error, _} -> {:error, {:extraction_failed, error}}
  end
end

# Build manifest with file hashes - recursively walk directory
defp build_manifest(dir) do
  dir
  |> list_files_recursive()
  |> Enum.reduce(%{}, fn file, acc ->
    content = File.read!(file)
    relative_path = Path.relative_to(file, dir)
    hash = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower) |> String.slice(0, 32)
    Map.put(acc, "/" <> relative_path, %{hash: hash, size: byte_size(content)})
  end)
end

defp list_files_recursive(dir) do
  dir
  |> File.ls!()
  |> Enum.flat_map(fn entry ->
    path = Path.join(dir, entry)
    if File.dir?(path), do: list_files_recursive(path), else: [path]
  end)
end
```

#### 2.3 Cloudflare API Client

```elixir
defmodule Upload.Deployer.Cloudflare.Client do
  @base_url "https://api.cloudflare.com/client/v4"

  def submit_manifest(script_name, manifest) do
    Req.post!(
      "#{@base_url}/accounts/#{account_id()}/workers/scripts/#{script_name}/assets-upload-session",
      json: manifest,
      headers: auth_headers()
    )
  end

  def upload_assets(files, jwt) do
    # Batch upload base64-encoded files
    Req.post!(
      "#{@base_url}/accounts/#{account_id()}/workers/assets/upload?base64=true",
      body: build_multipart(files),
      headers: [{"authorization", "Bearer #{jwt}"}, {"content-type", "multipart/form-data"}]
    )
  end

  def deploy_worker(script_name, worker_js, completion_jwt) do
    metadata = %{
      main_module: "worker.js",
      compatibility_date: Date.to_iso8601(Date.utc_today()),
      assets: %{jwt: completion_jwt}
    }

    Req.put!(
      "#{@base_url}/accounts/#{account_id()}/workers/scripts/#{script_name}",
      body: build_worker_multipart(worker_js, metadata),
      headers: auth_headers()
    )
  end

  def create_custom_domain(script_name, hostname) do
    Req.put!(
      "#{@base_url}/accounts/#{account_id()}/workers/domains",
      json: %{hostname: hostname, service: script_name, environment: "production"},
      headers: auth_headers()
    )
  end

  defp account_id, do: Application.fetch_env!(:upload, :cloudflare)[:account_id]

  defp auth_headers do
    token = Application.fetch_env!(:upload, :cloudflare)[:api_token]
    [{"authorization", "Bearer #{token}"}, {"content-type", "application/json"}]
  end
end
```

### Phase 3: Background Job Processing

#### 3.1 Add Oban for async deployment

```elixir
# mix.exs
{:oban, "~> 2.18"}

# lib/upload/application.ex
children = [
  {Oban, Application.fetch_env!(:upload, Oban)}
]

# config/config.exs
config :upload, Oban,
  repo: Upload.Repo,
  queues: [deployments: 2]
```

#### 3.2 Create deployment worker

```elixir
defmodule Upload.Workers.DeploymentWorker do
  use Oban.Worker, queue: :deployments, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"site_id" => site_id, "tarball_path" => path}}) do
    site = Sites.get_site!(site_id)
    Sites.update_site(site, %{deployment_status: "deploying"})

    case Upload.Deployer.Cloudflare.deploy(site, path) do
      {:ok, _} ->
        Sites.update_site(site, %{
          deployment_status: "deployed",
          last_deployed_at: DateTime.utc_now(),
          last_deployment_error: nil
        })
        :ok

      {:error, reason} ->
        Sites.update_site(site, %{
          deployment_status: "failed",
          last_deployment_error: inspect(reason)
        })
        {:error, reason}
    end
  end
end
```

### Phase 4: Integration with Upload Flow

#### 4.1 Update upload handlers

```elixir
# In DashboardLive and SiteUploadLive
def handle_event("save", _params, socket) do
  site = socket.assigns.site

  consume_uploaded_entries(socket, :tarball, fn %{path: path}, entry ->
    dest = Path.join(System.tmp_dir!(), "#{site.subdomain}_#{entry.uuid}.tar.gz")
    File.cp!(path, dest)

    # Queue deployment job
    %{site_id: site.id, tarball_path: dest}
    |> Upload.Workers.DeploymentWorker.new()
    |> Oban.insert()

    {:ok, dest}
  end)

  {:noreply,
   socket
   |> put_flash(:info, "Upload received! Deployment in progress...")
   |> push_navigate(to: ~p"/dashboard")}
end
```

### Phase 5: UI Updates

#### 5.1 Show deployment status on dashboard

Add status indicators to site cards:
- Pending (never deployed)
- Deploying (in progress)
- Deployed (with timestamp)
- Failed (with error message)

#### 5.2 Admin visibility

Add deployment logs/history to admin panel for troubleshooting.

---

## Cloudflare Setup Instructions (for Admin)

Since some setup requires Cloudflare dashboard access, document these steps:

1. **Create API Token**:
   - Go to Cloudflare Dashboard -> Profile -> API Tokens
   - Create token with permissions:
     - Account: Workers Scripts (Edit)
     - Zone: Workers Routes (Edit)
     - Zone: DNS (Edit) - for `nabaleague.com`

2. **Zone Configuration**:
   - Ensure `nabaleague.com` is added to Cloudflare
   - Note the Zone ID and Account ID

3. **Environment Variables**:
   ```bash
   CLOUDFLARE_ACCOUNT_ID=xxx
   CLOUDFLARE_API_TOKEN=xxx
   CLOUDFLARE_ZONE_ID=xxx
   ```

Workers are created automatically on first deployment. Custom domains are configured automatically.

---

## File Structure

```
lib/upload/
├── deployer/
│   ├── cloudflare.ex           # Main deployment orchestrator
│   └── cloudflare/
│       ├── client.ex           # HTTP API client
│       ├── manifest.ex         # Asset manifest builder
│       └── worker_template.ex  # Minimal worker JS template
├── workers/
│   └── deployment_worker.ex    # Oban job for async deployment
```

---

## Security Considerations

### File Type Allowlist

**IMPORTANT**: Only upload files with allowed extensions to prevent serving malicious content. The deployer must filter extracted files to only include common static website assets:

**Allowed extensions:**
- HTML: `.html`, `.htm`
- CSS: `.css`
- JavaScript: `.js`, `.mjs`
- Images: `.png`, `.jpg`, `.jpeg`, `.gif`, `.svg`, `.webp`, `.ico`, `.avif`
- Fonts: `.woff`, `.woff2`, `.ttf`, `.otf`, `.eot`
- Data: `.json`, `.xml`, `.txt`, `.md`
- Media: `.mp4`, `.webm`, `.mp3`, `.ogg`, `.wav`
- Other: `.map` (source maps), `.pdf`

Files with any other extensions should be **skipped** during the manifest building phase and logged for audit purposes.

```elixir
@allowed_extensions ~w(.html .htm .css .js .mjs .png .jpg .jpeg .gif .svg .webp .ico .avif .woff .woff2 .ttf .otf .eot .json .xml .txt .md .mp4 .webm .mp3 .ogg .wav .map .pdf)

defp allowed_file?(path) do
  ext = Path.extname(path) |> String.downcase()
  ext in @allowed_extensions
end

defp build_manifest(dir) do
  dir
  |> list_files_recursive()
  |> Enum.filter(&allowed_file?/1)  # Filter to allowed types only
  |> Enum.reduce(%{}, fn file, acc ->
    # ... existing manifest logic
  end)
end
```

### Path Traversal Prevention

Validate that extracted file paths don't contain `..` or absolute paths that could escape the extraction directory.

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| API rate limits | Batch asset uploads, implement exponential backoff |
| Large file uploads | Stream files, use chunked uploads for >100MB |
| Deployment failures | Oban retry logic, preserve previous worker version |
| Custom domain conflicts | Check domain availability before attempting |
| Malicious file uploads | Filter to allowed static file extensions only (see Security Considerations) |
| Path traversal attacks | Validate extracted paths don't escape extraction directory |

---

## Open Questions

1. **404 handling**: Should unknown paths return a 404 page or redirect to index.html (SPA mode)?
2. **Deployment history**: Do we need to track previous deployments for rollback?
3. **Webhooks**: Should we add webhook notifications on deployment success/failure now, or defer?
4. **Multiple hosting providers**: Is Cloudflare the only target, or should we design for Netlify too?

---

## References

- [Cloudflare Workers Static Assets](https://developers.cloudflare.com/workers/static-assets/)
- [Direct Upload API](https://developers.cloudflare.com/workers/static-assets/direct-upload/)
- [Custom Domains](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/)
- [Multipart Upload Metadata](https://developers.cloudflare.com/workers/configuration/multipart-upload-metadata/)
