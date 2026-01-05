defmodule Upload.Deployer.TarExtractorTest do
  use ExUnit.Case, async: true

  alias Upload.Deployer.TarExtractor

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "tar_extractor_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  describe "extract/2" do
    test "extracts tarball with ASCII filenames", %{tmp_dir: tmp_dir} do
      tarball_path = create_tarball(tmp_dir, %{"index.html" => "<html></html>"})
      extract_dir = Path.join(tmp_dir, "extract")

      assert {:ok, ^extract_dir} = TarExtractor.extract(tarball_path, extract_dir)
      assert File.exists?(Path.join(extract_dir, "index.html"))
      assert File.read!(Path.join(extract_dir, "index.html")) == "<html></html>"
    end

    test "extracts tarball with UTF-8 filenames", %{tmp_dir: tmp_dir} do
      files = %{
        "café.txt" => "café content",
        "東京.html" => "<html>Tokyo</html>",
        "münchen.jpg" => "munich"
      }

      tarball_path = create_tarball(tmp_dir, files)
      extract_dir = Path.join(tmp_dir, "extract")

      assert {:ok, ^extract_dir} = TarExtractor.extract(tarball_path, extract_dir)

      for {filename, content} <- files do
        file_path = Path.join(extract_dir, filename)
        assert File.exists?(file_path), "Expected #{filename} to exist"
        assert File.read!(file_path) == content
      end
    end

    test "extracts tarball with Latin-1 encoded filenames", %{tmp_dir: tmp_dir} do
      # Create a tarball with Latin-1 encoded filenames
      # This simulates what Windows tar creates
      tarball_path = create_latin1_tarball(tmp_dir)
      extract_dir = Path.join(tmp_dir, "extract")

      assert {:ok, ^extract_dir} = TarExtractor.extract(tarball_path, extract_dir)

      # The filename should be converted from Latin-1 to UTF-8
      # Latin-1 byte 0xF3 (ó) becomes UTF-8 0xC3 0xB3
      expected_filename = "córdoba_archers.png"
      file_path = Path.join(extract_dir, expected_filename)

      assert File.exists?(file_path), "Expected #{expected_filename} to exist with UTF-8 encoding"
      assert File.read!(file_path) == "fake png content"
    end

    test "extracts tarball with nested directories", %{tmp_dir: tmp_dir} do
      files = %{
        "images/logo.png" => "logo content",
        "data/stats.json" => ~s({"team": "test"}),
        "css/style.css" => "body { margin: 0; }"
      }

      tarball_path = create_tarball(tmp_dir, files)
      extract_dir = Path.join(tmp_dir, "extract")

      assert {:ok, ^extract_dir} = TarExtractor.extract(tarball_path, extract_dir)

      for {filename, content} <- files do
        file_path = Path.join(extract_dir, filename)
        assert File.exists?(file_path), "Expected #{filename} to exist"
        assert File.read!(file_path) == content
      end
    end

    test "extracts tarball with directories", %{tmp_dir: tmp_dir} do
      # Create a tarball that includes explicit directory entries
      source_dir = Path.join(tmp_dir, "source")
      File.mkdir_p!(Path.join(source_dir, "empty_dir"))
      File.write!(Path.join(source_dir, "file.txt"), "content")

      tarball_path = Path.join(tmp_dir, "test.tar.gz")
      {_, 0} = System.cmd("tar", ["-czf", tarball_path, "-C", source_dir, "."])

      extract_dir = Path.join(tmp_dir, "extract")

      assert {:ok, ^extract_dir} = TarExtractor.extract(tarball_path, extract_dir)
      assert File.dir?(Path.join(extract_dir, "empty_dir"))
      assert File.exists?(Path.join(extract_dir, "file.txt"))
    end

    test "returns error for non-existent tarball", %{tmp_dir: tmp_dir} do
      extract_dir = Path.join(tmp_dir, "extract")

      assert {:error, _} = TarExtractor.extract("/non/existent/file.tar.gz", extract_dir)
    end

    test "returns error for invalid gzip data", %{tmp_dir: tmp_dir} do
      # Create a file that's not a valid gzip
      invalid_file = Path.join(tmp_dir, "invalid.tar.gz")
      File.write!(invalid_file, "not a gzip file")

      extract_dir = Path.join(tmp_dir, "extract")

      assert {:error, {:gzip_decompression_failed, _}} =
               TarExtractor.extract(invalid_file, extract_dir)
    end

    test "detects and prevents path traversal", %{tmp_dir: tmp_dir} do
      # Create a tarball with path traversal attempt
      tarball_path = create_path_traversal_tarball(tmp_dir)
      extract_dir = Path.join(tmp_dir, "extract")

      # The extractor should detect the path traversal and return an error
      result = TarExtractor.extract(tarball_path, extract_dir)

      assert {:error, {:path_traversal_detected, _}} = result
    end
  end

  # Helper to create a tarball from a map of filename => content
  defp create_tarball(tmp_dir, files) do
    source_dir = Path.join(tmp_dir, "source_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(source_dir)

    for {filename, content} <- files do
      file_path = Path.join(source_dir, filename)
      File.mkdir_p!(Path.dirname(file_path))
      File.write!(file_path, content)
    end

    tarball_path = Path.join(tmp_dir, "test_#{:erlang.unique_integer([:positive])}.tar.gz")

    {_, 0} =
      System.cmd("tar", ["-czf", tarball_path, "-C", source_dir, "."],
        env: [{"LC_ALL", "en_US.UTF-8"}, {"LANG", "en_US.UTF-8"}]
      )

    tarball_path
  end

  # Helper to create a tarball with Latin-1 encoded filenames
  # This simulates what Windows tar creates
  defp create_latin1_tarball(tmp_dir) do
    # To create a Latin-1 encoded tar archive, we need to manually build the tar file
    # or use a system tar with Latin-1 locale
    # For testing, we'll try to use LC_ALL=C or latin1 locale

    source_dir = Path.join(tmp_dir, "latin1_source_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(source_dir)

    # Create a file with a name that will be encoded as Latin-1
    # We use the literal UTF-8 filename, but tar will encode it differently based on locale
    File.write!(Path.join(source_dir, "córdoba_archers.png"), "fake png content")

    tarball_path = Path.join(tmp_dir, "latin1_#{:erlang.unique_integer([:positive])}.tar.gz")

    # Try to create with Latin-1 locale (this may not work on all systems)
    # On systems without Latin-1 locale, this will fall back to creating with C locale
    case System.cmd(
           "tar",
           ["-czf", tarball_path, "-C", source_dir, "."],
           env: [{"LC_ALL", "C"}, {"LANG", "C"}],
           stderr_to_stdout: true
         ) do
      {_, 0} ->
        # On some systems (especially macOS), we can't create Latin-1 encoded archives
        # because the filesystem rejects non-UTF-8 filenames
        # For testing, we can manually craft a tar archive with Latin-1 bytes
        # or we can test with a pre-existing Latin-1 encoded archive

        # For now, let's try to manually create one
        manually_create_latin1_tar(tmp_dir, tarball_path)

      {error, _} ->
        # If tar fails, try manual creation
        IO.puts("tar with C locale failed: #{error}, trying manual creation")
        manually_create_latin1_tar(tmp_dir, tarball_path)
    end
  end

  # Manually create a tar.gz with Latin-1 encoded filename
  defp manually_create_latin1_tar(_tmp_dir, output_path) do
    # Create a minimal tar archive with a file that has a Latin-1 encoded name
    # "córdoba_archers.png" with ó as Latin-1 byte 0xF3

    file_content = "fake png content"
    file_size = byte_size(file_content)

    # Build tar header (512 bytes)
    # Filename with Latin-1 encoding: "c\xF3rdoba_archers.png"
    latin1_filename =
      <<99, 0xF3, 114, 100, 111, 98, 97, 95, 97, 114, 99, 104, 101, 114, 115, 46, 112, 110, 103>>

    # Pad filename to 100 bytes with nulls
    filename_field = String.pad_trailing(latin1_filename, 100, <<0>>)

    # File mode (644 in octal)
    mode_field = String.pad_trailing("0000644", 8, <<0>>)

    # UID and GID (0)
    uid_field = String.pad_trailing("0000000", 8, <<0>>)
    gid_field = String.pad_trailing("0000000", 8, <<0>>)

    # File size in octal
    size_octal = Integer.to_string(file_size, 8)
    size_field = String.pad_leading(size_octal, 11, "0") <> " "

    # Modification time (arbitrary)
    mtime_field = String.pad_trailing("14000000000", 12, <<0>>)

    # Checksum placeholder (8 spaces for now)
    checksum_placeholder = "        "

    # Type flag: '0' for regular file
    typeflag = "0"

    # Link name (empty, 100 bytes)
    linkname_field = String.duplicate(<<0>>, 100)

    # UStar magic and version
    ustar_magic = "ustar  "
    ustar_version = <<0, 0>>

    # Owner name and group name (empty)
    owner_field = String.duplicate(<<0>>, 32)
    group_field = String.duplicate(<<0>>, 32)

    # Device fields (empty)
    devmajor_field = String.duplicate(<<0>>, 8)
    devminor_field = String.duplicate(<<0>>, 8)

    # Prefix (empty, 155 bytes)
    prefix_field = String.duplicate(<<0>>, 155)

    # Padding to reach 512 bytes (12 bytes needed after prefix)
    padding_field = String.duplicate(<<0>>, 12)

    # Build header without checksum
    header_without_checksum =
      filename_field <>
        mode_field <>
        uid_field <>
        gid_field <>
        size_field <>
        mtime_field <>
        checksum_placeholder <>
        typeflag <>
        linkname_field <>
        ustar_magic <>
        ustar_version <>
        owner_field <>
        group_field <>
        devmajor_field <>
        devminor_field <>
        prefix_field <>
        padding_field

    # Calculate checksum (sum of all bytes, treating checksum field as spaces)
    checksum =
      header_without_checksum
      |> :binary.bin_to_list()
      |> Enum.sum()

    # Format checksum as 6-digit octal + null + space
    checksum_str = String.pad_leading(Integer.to_string(checksum, 8), 6, "0") <> <<0, 32>>

    # Build final header with checksum (replace bytes 148-155 with checksum)
    header =
      binary_part(header_without_checksum, 0, 148) <>
        checksum_str <>
        binary_part(header_without_checksum, 156, 512 - 156)

    # Pad file content to 512-byte boundary
    file_data_padded =
      if rem(file_size, 512) == 0 do
        file_content
      else
        padding_size = 512 - rem(file_size, 512)
        file_content <> String.duplicate(<<0>>, padding_size)
      end

    # Two empty blocks mark end of archive
    end_marker = String.duplicate(<<0>>, 1024)

    # Combine into tar archive
    tar_data = header <> file_data_padded <> end_marker

    # Compress with gzip
    gz_data = :zlib.gzip(tar_data)

    # Write to file
    File.write!(output_path, gz_data)

    output_path
  end

  # Helper to create a tarball with path traversal
  defp create_path_traversal_tarball(tmp_dir) do
    # Manually create a tar with "../escape.txt" in the filename
    file_content = "malicious content"
    file_size = byte_size(file_content)

    # Filename with path traversal
    traversal_filename = "../escape.txt"

    # Build tar header similar to manually_create_latin1_tar
    filename_field = String.pad_trailing(traversal_filename, 100, <<0>>)
    mode_field = String.pad_trailing("0000644", 8, <<0>>)
    uid_field = String.pad_trailing("0000000", 8, <<0>>)
    gid_field = String.pad_trailing("0000000", 8, <<0>>)
    size_octal = Integer.to_string(file_size, 8)
    size_field = String.pad_leading(size_octal, 11, "0") <> " "
    mtime_field = String.pad_trailing("14000000000", 12, <<0>>)
    checksum_placeholder = "        "
    typeflag = "0"
    linkname_field = String.duplicate(<<0>>, 100)
    ustar_magic = "ustar  "
    ustar_version = <<0, 0>>
    owner_field = String.duplicate(<<0>>, 32)
    group_field = String.duplicate(<<0>>, 32)
    devmajor_field = String.duplicate(<<0>>, 8)
    devminor_field = String.duplicate(<<0>>, 8)
    prefix_field = String.duplicate(<<0>>, 155)
    # Padding to reach 512 bytes
    padding_field = String.duplicate(<<0>>, 12)

    header_without_checksum =
      filename_field <>
        mode_field <>
        uid_field <>
        gid_field <>
        size_field <>
        mtime_field <>
        checksum_placeholder <>
        typeflag <>
        linkname_field <>
        ustar_magic <>
        ustar_version <>
        owner_field <>
        group_field <>
        devmajor_field <>
        devminor_field <>
        prefix_field <>
        padding_field

    checksum =
      header_without_checksum
      |> :binary.bin_to_list()
      |> Enum.sum()

    checksum_str = String.pad_leading(Integer.to_string(checksum, 8), 6, "0") <> <<0, 32>>

    header =
      binary_part(header_without_checksum, 0, 148) <>
        checksum_str <>
        binary_part(header_without_checksum, 156, 512 - 156)

    file_data_padded =
      if rem(file_size, 512) == 0 do
        file_content
      else
        padding_size = 512 - rem(file_size, 512)
        file_content <> String.duplicate(<<0>>, padding_size)
      end

    end_marker = String.duplicate(<<0>>, 1024)
    tar_data = header <> file_data_padded <> end_marker
    gz_data = :zlib.gzip(tar_data)

    tarball_path = Path.join(tmp_dir, "traversal_#{:erlang.unique_integer([:positive])}.tar.gz")
    File.write!(tarball_path, gz_data)

    tarball_path
  end
end
