defmodule Upload.Deployer.Cloudflare.Manifest do
  @moduledoc """
  Builds asset manifests for Cloudflare Workers deployment.

  The manifest contains file paths mapped to their SHA-256 hashes and sizes,
  which Cloudflare uses to determine which files need to be uploaded.
  """

  require Logger

  @allowed_extensions ~w(.html .htm .css .js .mjs .png .jpg .jpeg .gif .svg .webp .ico .avif .woff .woff2 .ttf .otf .eot .json .xml .txt .md .mp4 .webm .mp3 .ogg .wav .map .pdf)

  @doc """
  Builds a manifest from all files in the given directory.

  Returns a map where keys are URL paths (e.g., "/index.html") and values
  are maps containing `:hash` and `:size` keys.

  Files with disallowed extensions are skipped and logged for security.
  """
  def build(directory) do
    directory
    |> list_files_recursive()
    |> Enum.reduce(%{manifest: %{}, skipped: []}, fn file, acc ->
      if allowed_file?(file) do
        content = File.read!(file)
        relative_path = Path.relative_to(file, directory)
        hash = compute_hash(content)
        url_path = "/" <> relative_path

        %{
          acc
          | manifest: Map.put(acc.manifest, url_path, %{hash: hash, size: byte_size(content)})
        }
      else
        Logger.warning(skipped_file: file, reason: "disallowed_extension")
        %{acc | skipped: [file | acc.skipped]}
      end
    end)
  end

  @doc """
  Builds a manifest and returns only the manifest map, ignoring skipped files.
  """
  def build!(directory) do
    %{manifest: manifest} = build(directory)
    manifest
  end

  @doc """
  Returns a list of all files in the directory recursively.
  """
  def list_files_recursive(directory) do
    directory
    |> File.ls!()
    |> Enum.flat_map(fn entry ->
      path = Path.join(directory, entry)

      if File.dir?(path) do
        list_files_recursive(path)
      else
        [path]
      end
    end)
  end

  @doc """
  Checks if a file has an allowed extension.
  """
  def allowed_file?(path) do
    ext = path |> Path.extname() |> String.downcase()
    ext in @allowed_extensions
  end

  @doc """
  Computes a truncated SHA-256 hash for use in the manifest.

  Cloudflare expects a 32-character lowercase hex hash.
  """
  def compute_hash(content) do
    :crypto.hash(:sha256, content)
    |> Base.encode16(case: :lower)
    |> String.slice(0, 32)
  end

  @doc """
  Returns the list of allowed file extensions.
  """
  def allowed_extensions, do: @allowed_extensions
end
