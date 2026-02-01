defmodule Upload.Deployer.FormatRouter do
  @moduledoc """
  Handles routing rules for different OOTP export formats.

  Different versions of Out Of the Park Baseball export website files in
  different folder structures. This module provides routing logic to map
  incoming URL paths to the correct physical file locations based on the
  site's detected format version.

  ## Supported Formats

  - `ootp23`: OOTP 23+ format where files are located in `news/html/` subdirectory
    - Routes root `/` to `news/html/index.html`
    - Prepends `news/html/` to all other paths
  """

  @supported_formats ~w(ootp23)

  @doc """
  Returns the list of supported format versions.
  """
  def supported_formats, do: @supported_formats

  @doc """
  Routes a URL path to the physical file path based on the format version.

  ## Parameters

  - `format_version`: The format version string (e.g., "ootp23")
  - `path`: The URL path (e.g., "/", "/teams/index.html", "/styles.css")

  ## Returns

  The routed path that should be used when looking up files in the filesystem.

  ## Examples

      iex> FormatRouter.route_path("ootp23", "/")
      "news/html/index.html"

      iex> FormatRouter.route_path("ootp23", "/teams/team_1.html")
      "news/html/teams/team_1.html"

      iex> FormatRouter.route_path("ootp23", "/styles.css")
      "news/html/styles.css"

  """
  def route_path(format_version, path)

  def route_path("ootp23", "/") do
    "news/html/index.html"
  end

  def route_path("ootp23", path) when is_binary(path) do
    # Remove leading slash if present
    relative_path = String.trim_leading(path, "/")
    Path.join("news/html", relative_path)
  end

  def route_path(_unsupported_format, path) do
    # For unsupported formats, return path as-is (fallback behavior)
    String.trim_leading(path, "/")
  end

  @doc """
  Validates if a format version is supported.

  ## Examples

      iex> FormatRouter.valid_format?("ootp23")
      true

      iex> FormatRouter.valid_format?("unknown")
      false

  """
  def valid_format?(format_version) do
    format_version in @supported_formats
  end

  @doc """
  Returns the default format version for new sites.
  """
  def default_format, do: "ootp23"
end
