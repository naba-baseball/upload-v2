defmodule Upload.FileValidator do
  @moduledoc """
  Validates uploaded files for security and correctness.
  """

  # Gzip magic bytes: 1f 8b
  @gzip_magic_bytes <<0x1F, 0x8B>>

  @doc """
  Validates that a file is a valid gzip archive by checking its magic bytes.

  Returns `:ok` if valid, `{:error, reason}` otherwise.

  ## Examples

      iex> Upload.FileValidator.validate_gzip("/path/to/valid.tar.gz")
      :ok

      iex> Upload.FileValidator.validate_gzip("/path/to/fake.tar.gz")
      {:error, :invalid_gzip_format}
  """
  @spec validate_gzip(Path.t()) :: :ok | {:error, :invalid_gzip_format | :file_read_error}
  def validate_gzip(path) do
    case File.open(path, [:read, :binary]) do
      {:ok, file} ->
        result =
          case IO.binread(file, 2) do
            @gzip_magic_bytes -> :ok
            _ -> {:error, :invalid_gzip_format}
          end

        File.close(file)
        result

      {:error, _reason} ->
        {:error, :file_read_error}
    end
  end

  @doc """
  Returns a human-readable error message for validation errors.
  """
  @spec error_message(:invalid_gzip_format | :file_read_error | :file_copy_error) :: String.t()
  def error_message(:invalid_gzip_format),
    do: "File is not a valid gzip archive. Please upload a .tar.gz file."

  def error_message(:file_read_error),
    do: "Unable to read uploaded file. Please try again."

  def error_message(:file_copy_error),
    do: "Unable to save uploaded file. Please try again."
end
