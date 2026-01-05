defmodule Upload.Deployer.CloudflareTest do
  use ExUnit.Case, async: true

  alias Upload.Deployer.Cloudflare
  alias Upload.Deployer.Cloudflare.Client

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "cloudflare_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  describe "Client.submit_manifest/2 with missing config" do
    test "returns error when account_id is not configured" do
      # Ensure cloudflare config is empty/missing
      original_config = Application.get_env(:upload, :cloudflare)
      Application.put_env(:upload, :cloudflare, [])

      on_exit(fn ->
        if original_config do
          Application.put_env(:upload, :cloudflare, original_config)
        else
          Application.delete_env(:upload, :cloudflare)
        end
      end)

      result = Client.submit_manifest("test-worker", %{})

      assert result == {:error, :missing_cloudflare_config}
    end

    test "returns error when api_token is not configured" do
      original_config = Application.get_env(:upload, :cloudflare)
      Application.put_env(:upload, :cloudflare, account_id: "test-account")

      on_exit(fn ->
        if original_config do
          Application.put_env(:upload, :cloudflare, original_config)
        else
          Application.delete_env(:upload, :cloudflare)
        end
      end)

      result = Client.submit_manifest("test-worker", %{})

      assert result == {:error, :missing_cloudflare_config}
    end
  end

  describe "Client.upload_assets/2 with missing config" do
    test "returns error when account_id is not configured" do
      original_config = Application.get_env(:upload, :cloudflare)
      Application.put_env(:upload, :cloudflare, [])

      on_exit(fn ->
        if original_config do
          Application.put_env(:upload, :cloudflare, original_config)
        else
          Application.delete_env(:upload, :cloudflare)
        end
      end)

      result = Client.upload_assets([], "fake-jwt")

      assert result == {:error, :missing_cloudflare_config}
    end
  end

  describe "Client.get_completion_jwt/1 with missing config" do
    test "returns error when account_id is not configured" do
      original_config = Application.get_env(:upload, :cloudflare)
      Application.put_env(:upload, :cloudflare, [])

      on_exit(fn ->
        if original_config do
          Application.put_env(:upload, :cloudflare, original_config)
        else
          Application.delete_env(:upload, :cloudflare)
        end
      end)

      result = Client.get_completion_jwt("fake-jwt")

      assert result == {:error, :missing_cloudflare_config}
    end
  end

  describe "Client.deploy_worker/3 with missing config" do
    test "returns error when account_id is not configured" do
      original_config = Application.get_env(:upload, :cloudflare)
      Application.put_env(:upload, :cloudflare, [])

      on_exit(fn ->
        if original_config do
          Application.put_env(:upload, :cloudflare, original_config)
        else
          Application.delete_env(:upload, :cloudflare)
        end
      end)

      result = Client.deploy_worker("test-worker", "js code", %{})

      assert result == {:error, :missing_cloudflare_config}
    end
  end

  describe "Client.create_custom_domain/2 with missing config" do
    test "returns error when account_id is not configured" do
      original_config = Application.get_env(:upload, :cloudflare)
      Application.put_env(:upload, :cloudflare, [])

      on_exit(fn ->
        if original_config do
          Application.put_env(:upload, :cloudflare, original_config)
        else
          Application.delete_env(:upload, :cloudflare)
        end
      end)

      result = Client.create_custom_domain("test-worker", "example.com")

      assert result == {:error, :missing_cloudflare_config}
    end
  end

  describe "Client.worker_exists?/1 with missing config" do
    test "returns error when account_id is not configured" do
      original_config = Application.get_env(:upload, :cloudflare)
      Application.put_env(:upload, :cloudflare, [])

      on_exit(fn ->
        if original_config do
          Application.put_env(:upload, :cloudflare, original_config)
        else
          Application.delete_env(:upload, :cloudflare)
        end
      end)

      result = Client.worker_exists?("test-worker")

      assert result == {:error, :missing_cloudflare_config}
    end
  end

  describe "extract_tarball/1" do
    test "extracts tarball with ASCII filenames", %{tmp_dir: tmp_dir} do
      tarball_path = create_tarball(tmp_dir, %{"index.html" => "<html></html>"})

      assert {:ok, extract_dir} = Cloudflare.extract_tarball(tarball_path)
      assert File.exists?(Path.join(extract_dir, "index.html"))

      # Cleanup
      File.rm_rf!(extract_dir)
    end

    test "extracts tarball with non-ASCII UTF-8 filenames", %{tmp_dir: tmp_dir} do
      # Regression test for "Illegal byte sequence" error with non-ASCII filenames
      files = %{
        "córdoba_archers.png" => "fake png content",
        "münchen_team.jpg" => "fake jpg content",
        "東京_league.html" => "<html>Tokyo</html>",
        "café_roster.txt" => "roster data"
      }

      tarball_path = create_tarball(tmp_dir, files)

      assert {:ok, extract_dir} = Cloudflare.extract_tarball(tarball_path)

      for {filename, content} <- files do
        file_path = Path.join(extract_dir, filename)
        assert File.exists?(file_path), "Expected #{filename} to exist"
        assert File.read!(file_path) == content
      end

      # Cleanup
      File.rm_rf!(extract_dir)
    end

    test "extracts tarball with nested directories containing non-ASCII names", %{
      tmp_dir: tmp_dir
    } do
      files = %{
        "images/équipe/logo.png" => "logo content",
        "data/España/stats.json" => ~s({"team": "España"})
      }

      tarball_path = create_tarball(tmp_dir, files)

      assert {:ok, extract_dir} = Cloudflare.extract_tarball(tarball_path)

      for {filename, content} <- files do
        file_path = Path.join(extract_dir, filename)
        assert File.exists?(file_path), "Expected #{filename} to exist"
        assert File.read!(file_path) == content
      end

      # Cleanup
      File.rm_rf!(extract_dir)
    end

    test "returns error for non-existent tarball" do
      assert {:error, {:file_stat_failed, :enoent}} =
               Cloudflare.extract_tarball("/non/existent/file.tar.gz")
    end

    test "returns error for path traversal attempts and prevents escape", %{tmp_dir: tmp_dir} do
      # Create a tarball with path traversal attempt
      tarball_path = create_malicious_tarball(tmp_dir)

      # Attempt extraction should fail
      assert {:error, {:path_traversal_detected, _}} = Cloudflare.extract_tarball(tarball_path)

      # Verify that no files were created outside the extraction directory
      # or with parent directory references (../.. content should never exist)
      parent_dir = Path.dirname(tmp_dir)
      escaped_file = Path.join(parent_dir, "escape.txt")

      refute File.exists?(escaped_file),
             "Security breach: extracted file escaped the archive directory"
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

  # Helper to create a tarball with path traversal (manually crafted)
  defp create_malicious_tarball(tmp_dir) do
    file_content = "malicious content"
    file_size = byte_size(file_content)

    # Filename with path traversal
    traversal_filename = "../escape.txt"

    # Build tar header manually (512 bytes total)
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
