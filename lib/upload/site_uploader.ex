defmodule Upload.SiteUploader do
  @moduledoc """
  Handles processing of uploaded site archives.

  This module centralizes the upload validation and storage logic
  to ensure consistent security checks across all upload entry points.
  """

  alias Upload.FileValidator
  alias Upload.Sites.Site

  @type upload_result :: {:ok, Path.t()} | {:error, :invalid_gzip_format | :file_read_error}

  @doc """
  Processes an uploaded file for a site.

  Validates the file is a valid gzip archive, then copies it to a
  temporary location for further processing.

  Returns `{:ok, destination_path}` on success or `{:error, reason}` on failure.
  """
  @spec process_upload(Path.t(), %Site{}, String.t()) :: upload_result()
  def process_upload(source_path, site, entry_uuid) do
    case FileValidator.validate_gzip(source_path) do
      :ok ->
        dest = build_destination_path(site, entry_uuid)
        File.cp!(source_path, dest)
        {:ok, dest}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp build_destination_path(site, entry_uuid) do
    Path.join(System.tmp_dir!(), "#{site.subdomain}_#{entry_uuid}.tar.gz")
  end
end
