defmodule UploadWeb.Plugs.SubdomainRouter do
  @moduledoc """
  Routes subdomain requests to serve static site files.

  Intercepts requests to subdomains (e.g., mysite.example.com or mysite.localhost)
  and serves static files from priv/static/sites/{subdomain}/.
  """

  import Plug.Conn
  require Logger

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    case extract_routing_info(conn) do
      {:subdomain, subdomain} ->
        handle_site_request(conn, subdomain, :subdomain)

      {:subpath, subdomain} ->
        handle_site_request(conn, subdomain, :subpath)

      :no_match ->
        # No site routing detected - pass through to normal routing
        conn
    end
  end

  defp extract_routing_info(conn) do
    # Try subpath first (more specific match)
    case extract_subpath(conn) do
      {:ok, subdomain} ->
        {:subpath, subdomain}

      :no_match ->
        # Fall back to subdomain detection
        case extract_subdomain(conn) do
          nil -> :no_match
          subdomain -> {:subdomain, subdomain}
        end
    end
  end

  defp extract_subpath(conn) do
    # Match /sites/{subdomain} and extract subdomain
    case String.split(conn.request_path, "/", parts: 4) do
      ["", "sites", subdomain | _] when subdomain != "" ->
        # Validate subdomain format (same as schema validation)
        if subdomain =~ ~r/^[a-z0-9-]+$/ do
          {:ok, subdomain}
        else
          :no_match
        end

      _ ->
        :no_match
    end
  end

  defp handle_site_request(conn, subdomain, routing_type) do
    case Upload.Sites.get_site_by_subdomain(subdomain) do
      nil ->
        # Site not found - pass through to normal routing
        conn

      site ->
        # Verify routing mode allows this access method
        if routing_allowed?(site.routing_mode, routing_type) do
          serve_site_file(conn, site, routing_type)
        else
          # Mode doesn't allow this routing method - pass through
          conn
        end
    end
  end

  defp routing_allowed?("subdomain", :subdomain), do: true
  defp routing_allowed?("subpath", :subpath), do: true
  defp routing_allowed?("both", _), do: true
  defp routing_allowed?(_, _), do: false

  defp extract_subdomain(conn) do
    host = get_host(conn)
    base_domain = Application.get_env(:upload, :base_domain)

    cond do
      # Development: subdomain.localhost
      String.ends_with?(host, ".localhost") ->
        host
        |> String.replace_suffix(".localhost", "")
        |> case do
          # Just localhost, no subdomain
          "localhost" -> nil
          subdomain -> subdomain
        end

      # Production: subdomain.base_domain
      String.ends_with?(host, ".#{base_domain}") ->
        host
        |> String.replace_suffix(".#{base_domain}", "")
        |> case do
          # Just the base domain, no subdomain
          ^base_domain -> nil
          subdomain -> subdomain
        end

      # No subdomain detected
      true ->
        nil
    end
  end

  defp get_host(conn) do
    # First check conn.host (set directly on conn struct, used in tests)
    # Then fall back to the host header
    host =
      if conn.host && conn.host != "" do
        conn.host
      else
        case get_req_header(conn, "host") do
          [header_host | _] -> header_host
          _ -> ""
        end
      end

    # Remove port if present
    host
    |> String.split(":")
    |> List.first()
  end

  defp serve_site_file(conn, site, routing_type) do
    # Only serve for deployed sites
    if site.deployment_status == "deployed" do
      # Adjust path for subpath routing
      path =
        case routing_type do
          :subpath ->
            strip_subpath_prefix(conn.request_path, site.subdomain)

          :subdomain ->
            conn.request_path
        end

      normalized_path = normalize_path(path)
      site_dir = Path.join([:code.priv_dir(:upload), "static", "sites", site.subdomain])

      # Try to serve the requested file or fall back to index.html patterns
      file_path = resolve_file_path(site_dir, normalized_path)

      case file_path do
        {:ok, resolved_path} ->
          # Security check: ensure resolved path is within site directory
          if path_safe?(resolved_path, site_dir) do
            serve_file(conn, resolved_path)
          else
            Logger.warning("Path traversal attempt detected: #{path} for site #{site.subdomain}")
            send_404(conn)
          end

        {:error, :not_found} ->
          send_404(conn)
      end
    else
      # Site not yet deployed - pass through to normal routing
      conn
    end
  end

  defp strip_subpath_prefix(path, subdomain) do
    prefix = "/sites/#{subdomain}"

    case String.split(path, prefix, parts: 2) do
      [_, remaining] ->
        if remaining == "", do: "/", else: remaining

      _ ->
        path
    end
  end

  defp normalize_path(path) do
    # Remove query string and normalize slashes
    path
    |> String.split("?")
    |> List.first()
    |> String.trim_trailing("/")
    |> case do
      "" -> "/"
      normalized -> normalized
    end
  end

  defp resolve_file_path(site_dir, "/") do
    # Root path - serve index.html
    index_path = Path.join(site_dir, "index.html")
    if File.exists?(index_path), do: {:ok, index_path}, else: {:error, :not_found}
  end

  defp resolve_file_path(site_dir, path) do
    # Remove leading slash
    relative_path = String.trim_leading(path, "/")
    full_path = Path.join(site_dir, relative_path)

    cond do
      # Exact file exists
      File.exists?(full_path) and !File.dir?(full_path) ->
        {:ok, full_path}

      # Directory - try index.html
      File.dir?(full_path) ->
        index_path = Path.join(full_path, "index.html")
        if File.exists?(index_path), do: {:ok, index_path}, else: {:error, :not_found}

      # Try adding .html extension for clean URLs
      true ->
        html_path = full_path <> ".html"
        if File.exists?(html_path), do: {:ok, html_path}, else: {:error, :not_found}
    end
  end

  defp path_safe?(file_path, site_dir) do
    # Expand both paths to absolute paths and ensure file is within site directory
    expanded_file = Path.expand(file_path)
    expanded_site = Path.expand(site_dir)

    String.starts_with?(expanded_file, expanded_site <> "/") or expanded_file == expanded_site
  end

  defp serve_file(conn, file_path) do
    content_type = MIME.from_path(file_path)
    cache_control = cache_control_header(file_path)

    conn
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("cache-control", cache_control)
    |> send_file(200, file_path)
    |> halt()
  end

  defp cache_control_header(file_path) do
    ext = Path.extname(file_path)

    if ext in [".html", ".htm"] do
      # HTML files: 1 hour cache
      "public, max-age=3600"
    else
      # Assets (CSS, JS, images, etc): 1 year cache
      "public, max-age=31536000, immutable"
    end
  end

  defp send_404(conn) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(404, """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>404 Not Found</title>
      <style>
        body {
          font-family: system-ui, -apple-system, sans-serif;
          display: flex;
          align-items: center;
          justify-content: center;
          height: 100vh;
          margin: 0;
          background: #f3f4f6;
        }
        .container {
          text-align: center;
          padding: 2rem;
        }
        h1 {
          font-size: 3rem;
          margin: 0;
          color: #1f2937;
        }
        p {
          font-size: 1.25rem;
          color: #6b7280;
        }
      </style>
    </head>
    <body>
      <div class="container">
        <h1>404</h1>
        <p>Page not found</p>
      </div>
    </body>
    </html>
    """)
    |> halt()
  end
end
