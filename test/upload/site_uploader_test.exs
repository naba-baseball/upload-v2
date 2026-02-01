defmodule Upload.SiteUploaderTest do
  use ExUnit.Case, async: true

  alias Upload.SiteUploader
  alias Upload.Sites.Site

  @valid_gzip_header <<0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03>>
  @invalid_content "This is not a gzip file"

  setup do
    tmp_dir = Path.join(System.tmp_dir!(), "site_uploader_test_#{:erlang.unique_integer()}")
    File.mkdir_p!(tmp_dir)

    site = %Site{
      id: 1,
      name: "Test Site",
      subdomain: "test-site"
    }

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir, site: site}
  end

  describe "process_upload/3" do
    test "returns {:ok, path} for valid gzip file", %{tmp_dir: tmp_dir, site: site} do
      source = Path.join(tmp_dir, "source.tar.gz")
      File.write!(source, @valid_gzip_header <> "compressed content")

      entry_uuid = "test-uuid-123"

      assert {:ok, dest} = SiteUploader.process_upload(source, site, entry_uuid)
      assert dest =~ "test-site_test-uuid-123.tar.gz"
      assert File.exists?(dest)

      # Cleanup
      File.rm(dest)
    end

    test "returns {:error, :invalid_gzip_format} for invalid file", %{
      tmp_dir: tmp_dir,
      site: site
    } do
      source = Path.join(tmp_dir, "invalid.tar.gz")
      File.write!(source, @invalid_content)

      assert {:error, :invalid_gzip_format} =
               SiteUploader.process_upload(source, site, "uuid-456")
    end

    test "returns {:error, :file_read_error} for non-existent file", %{site: site} do
      assert {:error, :file_read_error} =
               SiteUploader.process_upload("/non/existent/file.tar.gz", site, "uuid-789")
    end

    test "copies file content correctly", %{tmp_dir: tmp_dir, site: site} do
      source = Path.join(tmp_dir, "source.tar.gz")
      content = @valid_gzip_header <> "test content"
      File.write!(source, content)

      {:ok, dest} = SiteUploader.process_upload(source, site, "unique-id")

      assert File.read!(dest) == content

      # Cleanup
      File.rm(dest)
    end

    test "builds destination path with subdomain and uuid", %{tmp_dir: tmp_dir, site: site} do
      source = Path.join(tmp_dir, "source.tar.gz")
      File.write!(source, @valid_gzip_header)

      {:ok, dest} = SiteUploader.process_upload(source, site, "my-unique-id")

      assert String.ends_with?(dest, "test-site_my-unique-id.tar.gz")

      # Cleanup
      File.rm(dest)
    end
  end
end
