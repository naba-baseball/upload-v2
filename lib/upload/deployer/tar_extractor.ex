defmodule Upload.Deployer.TarExtractor do
  @moduledoc """
  Pure Elixir tar.gz extractor with Latin-1 to UTF-8 filename conversion.

  This module replaces `System.cmd("tar", ...)` to handle tar archives that
  contain filenames encoded in Latin-1 (ISO-8859-1) instead of UTF-8.

  ## Problem
  Tar archives created on Windows may contain filenames with Latin-1 encoding
  (e.g., `córdoba_archers.png` with byte 0xF3 instead of UTF-8 0xC3 0xB3).
  This causes extraction failures on macOS (APFS requires UTF-8) and routing
  issues on Linux.

  ## Solution
  1. Decompress gzip data
  2. Parse tar headers (512-byte blocks)
  3. Detect non-UTF-8 filenames with String.valid?/1
  4. Convert Latin-1 bytes to UTF-8
  5. Filter out macOS resource fork files (._* AppleDouble format)
  6. Extract files with correct UTF-8 filenames

  ## Limitations

  This extractor supports UStar format tar archives. Extended headers
  (PAX 'x' or GNU 'L' for long filenames) are skipped. This is acceptable
  for static site archives which typically contain short, web-safe filenames.

  ## Security

  - Path traversal attacks are blocked at write time
  - Compressed file size is limited to 500 MB (matches upload limit)
  - Decompressed size is limited to 1 GB to prevent zip bomb attacks
  """

  require Logger

  @block_size 512
  @name_offset 0
  @name_size 100
  @size_offset 124
  @size_length 12
  @type_offset 156
  @prefix_offset 345
  @prefix_size 155

  @typeflag_regular "0"
  @typeflag_regular_old "\0"
  @typeflag_directory "5"

  # Size limits to prevent zip bomb attacks
  # 500 MB compressed (matches upload limit)
  @max_compressed_size 524_288_000
  # 1 GB decompressed
  @max_decompressed_size 1_073_741_824

  # Pre-computed zero block for efficient end-of-archive detection
  @zero_block :binary.copy(<<0>>, @block_size)

  @doc """
  Extracts a .tar.gz file to the specified directory.

  Returns `{:ok, extract_dir}` on success or `{:error, reason}` on failure.

  ## Examples

      iex> TarExtractor.extract("/tmp/archive.tar.gz", "/tmp/output")
      {:ok, "/tmp/output"}
  """
  def extract(tarball_path, extract_dir) do
    with :ok <- validate_compressed_size(tarball_path),
         {:ok, gz_data} <- File.read(tarball_path),
         {:ok, tar_data} <- decompress_gzip(gz_data),
         :ok <- extract_tar(tar_data, extract_dir) do
      {:ok, extract_dir}
    else
      {:error, reason} = error ->
        Logger.error(tar_extraction_failed: tarball_path, reason: reason)
        error
    end
  end

  defp validate_compressed_size(tarball_path) do
    case File.stat(tarball_path) do
      {:ok, %{size: size}} when size <= @max_compressed_size ->
        :ok

      {:ok, %{size: size}} ->
        {:error, {:file_too_large, size, @max_compressed_size}}

      {:error, reason} ->
        {:error, {:file_stat_failed, reason}}
    end
  end

  # Decompress gzip data with size limit to prevent zip bomb attacks.
  # Uses streaming decompression to validate size during decompression rather than after.
  defp decompress_gzip(gz_data) do
    try do
      z = :zlib.open()

      try do
        # 16 for gzip format, 15 for max window bits
        :ok = :zlib.inflateInit(z, 16 + 15)
        tar_data = decompress_stream(z, gz_data, 0, <<>>)
        :zlib.close(z)
        {:ok, tar_data}
      rescue
        e ->
          :zlib.close(z)
          {:error, {:gzip_decompression_failed, Exception.message(e)}}
      end
    rescue
      e ->
        {:error, {:gzip_decompression_failed, Exception.message(e)}}
    end
  end

  # Stream-based decompression with size limit validation
  defp decompress_stream(z, input, input_offset, acc) when input_offset >= byte_size(input) do
    # All input processed, finalize decompression
    case :zlib.inflate(z, []) do
      [] ->
        acc

      data ->
        validate_and_add_data(acc, to_binary(data))
    end
  end

  defp decompress_stream(z, input, input_offset, acc) do
    # Process input in chunks to enable size checking during decompression
    chunk_size = min(16_384, byte_size(input) - input_offset)
    chunk = binary_part(input, input_offset, chunk_size)

    case :zlib.inflate(z, chunk) do
      [] ->
        # No output yet, continue reading input
        decompress_stream(z, input, input_offset + chunk_size, acc)

      data ->
        new_acc = validate_and_add_data(acc, to_binary(data))
        decompress_stream(z, input, input_offset + chunk_size, new_acc)
    end
  end

  # Convert zlib output (which may be a list of binaries) to a single binary
  defp to_binary(data) when is_list(data), do: IO.iodata_to_binary(data)
  defp to_binary(data) when is_binary(data), do: data

  # Validate and accumulate decompressed data, checking size limits
  defp validate_and_add_data(acc, data) do
    new_acc = acc <> data
    size = byte_size(new_acc)

    if size <= @max_decompressed_size do
      new_acc
    else
      raise "Decompressed data exceeds #{@max_decompressed_size} bytes limit (current: #{size})"
    end
  end

  # Extract tar data to directory
  defp extract_tar(tar_data, extract_dir) do
    File.mkdir_p!(extract_dir)
    parse_tar_blocks(tar_data, extract_dir, 0)
  end

  # Parse tar blocks recursively
  defp parse_tar_blocks(tar_data, _extract_dir, offset)
       when byte_size(tar_data) - offset < @block_size do
    # End of archive (or padding)
    :ok
  end

  defp parse_tar_blocks(tar_data, extract_dir, offset) do
    header = binary_part(tar_data, offset, @block_size)

    # Check if this is an empty block (end of archive marker)
    if all_zeros?(header) do
      :ok
    else
      case parse_header(header) do
        {:ok, file_info} ->
          # Extract the file data
          data_offset = offset + @block_size
          file_data = binary_part(tar_data, data_offset, file_info.size)

          # Write file to disk
          case write_file(extract_dir, file_info, file_data) do
            :ok ->
              # Calculate next offset (file data is padded to block size)
              padded_size = round_up_to_block_size(file_info.size)
              next_offset = data_offset + padded_size
              parse_tar_blocks(tar_data, extract_dir, next_offset)

            {:error, _} = error ->
              error
          end

        {:skip, size} ->
          # Skip this entry (e.g., special file types we don't support)
          padded_size = round_up_to_block_size(size)
          next_offset = offset + @block_size + padded_size
          parse_tar_blocks(tar_data, extract_dir, next_offset)
      end
    end
  end

  # Parse a tar header block
  defp parse_header(header) do
    # Extract raw filename components
    raw_name = binary_part(header, @name_offset, @name_size)
    raw_prefix = binary_part(header, @prefix_offset, @prefix_size)
    typeflag = binary_part(header, @type_offset, 1)

    # Extract and parse size (octal string)
    size_bytes = binary_part(header, @size_offset, @size_length)
    size = parse_octal(size_bytes)

    # Build full filename from prefix and name
    name = extract_null_terminated_string(raw_name)
    prefix = extract_null_terminated_string(raw_prefix)

    full_path =
      case prefix do
        "" -> name
        _ -> "#{prefix}/#{name}"
      end

    # Convert filename encoding if necessary
    utf8_path = ensure_utf8(full_path)

    # Skip macOS resource fork files (AppleDouble format)
    # These are metadata files created by macOS with ._ prefix
    if macos_resource_fork?(utf8_path) do
      {:skip, size}
    else
      # Only extract regular files and directories
      case typeflag do
        @typeflag_regular ->
          {:ok, %{path: utf8_path, size: size, type: :file}}

        @typeflag_regular_old ->
          {:ok, %{path: utf8_path, size: size, type: :file}}

        @typeflag_directory ->
          {:ok, %{path: utf8_path, size: 0, type: :directory}}

        _ ->
          # Skip other file types (symlinks, etc.)
          {:skip, size}
      end
    end
  end

  # Check if file is a macOS resource fork file (AppleDouble format)
  # These files start with ._ and contain metadata/extended attributes
  defp macos_resource_fork?(path) do
    path
    |> Path.basename()
    |> String.starts_with?("._")
  end

  # Extract null-terminated string from binary
  defp extract_null_terminated_string(binary) do
    case :binary.split(binary, <<0>>) do
      [str, _] -> str
      [str] -> str
    end
  end

  # Parse octal string to integer
  defp parse_octal(binary) do
    binary
    |> extract_null_terminated_string()
    |> String.trim()
    |> case do
      "" -> 0
      octal_str -> String.to_integer(octal_str, 8)
    end
  rescue
    _ -> 0
  end

  # Ensure filename is valid UTF-8, converting from Latin-1 if necessary.
  #
  # Latin-1 (ISO-8859-1) bytes 0x00-0xFF map directly to Unicode codepoints
  # U+0000 to U+00FF. This allows a simple conversion:
  # 1. :binary.bin_to_list/1 returns each byte as an integer (0-255)
  # 2. List.to_string/1 interprets those integers as Unicode codepoints
  # 3. The result is valid UTF-8 representing the same characters
  defp ensure_utf8(filename) when is_binary(filename) do
    if String.valid?(filename) do
      filename
    else
      filename
      |> :binary.bin_to_list()
      |> List.to_string()
    end
  end

  # Write file or create directory
  defp write_file(extract_dir, %{type: :directory, path: path}, _data) do
    full_path = Path.join(extract_dir, path)

    # Security: ensure no path traversal
    if path_traversal?(extract_dir, full_path) do
      {:error, {:path_traversal_detected, path}}
    else
      File.mkdir_p!(full_path)
      :ok
    end
  end

  defp write_file(extract_dir, %{type: :file, path: path}, data) do
    full_path = Path.join(extract_dir, path)

    # Security: ensure no path traversal
    if path_traversal?(extract_dir, full_path) do
      {:error, {:path_traversal_detected, path}}
    else
      # Ensure parent directory exists
      full_path |> Path.dirname() |> File.mkdir_p!()

      # Write file
      File.write!(full_path, data)
      :ok
    end
  rescue
    e ->
      {:error, {:file_write_failed, path, Exception.message(e)}}
  end

  # Check if path contains traversal attempts
  defp path_traversal?(extract_dir, full_path) do
    canonical_extract = Path.expand(extract_dir)
    canonical_full = Path.expand(full_path)

    not String.starts_with?(canonical_full, canonical_extract)
  end

  # Round up to next block size
  defp round_up_to_block_size(size) do
    remainder = rem(size, @block_size)

    if remainder == 0 do
      size
    else
      size + (@block_size - remainder)
    end
  end

  # Check if block is all zeros (end-of-archive marker)
  defp all_zeros?(block), do: block == @zero_block
end
