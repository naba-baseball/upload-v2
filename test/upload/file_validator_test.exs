defmodule Upload.FileValidatorTest do
  use ExUnit.Case, async: true

  alias Upload.FileValidator

  @valid_gzip_header <<0x1F, 0x8B, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03>>
  @invalid_content "This is not a gzip file"

  setup do
    # Create a temporary directory for test files
    tmp_dir = Path.join(System.tmp_dir!(), "file_validator_test_#{:erlang.unique_integer()}")
    File.mkdir_p!(tmp_dir)

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
  end

  describe "validate_gzip/1" do
    test "returns :ok for valid gzip file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "valid.tar.gz")
      # Write valid gzip magic bytes followed by some content
      File.write!(path, @valid_gzip_header <> "compressed data here")

      assert :ok = FileValidator.validate_gzip(path)
    end

    test "returns error for file without gzip magic bytes", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "invalid.tar.gz")
      File.write!(path, @invalid_content)

      assert {:error, :invalid_gzip_format} = FileValidator.validate_gzip(path)
    end

    test "returns error for empty file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "empty.tar.gz")
      File.write!(path, "")

      assert {:error, :invalid_gzip_format} = FileValidator.validate_gzip(path)
    end

    test "returns error for file with only one byte", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "single_byte.tar.gz")
      File.write!(path, <<0x1F>>)

      assert {:error, :invalid_gzip_format} = FileValidator.validate_gzip(path)
    end

    test "returns error for file with wrong first byte", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "wrong_first.tar.gz")
      # Correct second byte, wrong first byte
      File.write!(path, <<0x00, 0x8B, 0x08>>)

      assert {:error, :invalid_gzip_format} = FileValidator.validate_gzip(path)
    end

    test "returns error for file with wrong second byte", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "wrong_second.tar.gz")
      # Correct first byte, wrong second byte
      File.write!(path, <<0x1F, 0x00, 0x08>>)

      assert {:error, :invalid_gzip_format} = FileValidator.validate_gzip(path)
    end

    test "returns error for non-existent file" do
      path = "/non/existent/path/file.tar.gz"

      assert {:error, :file_read_error} = FileValidator.validate_gzip(path)
    end

    test "returns error for PDF file disguised as gzip", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "fake.tar.gz")
      # PDF magic bytes
      File.write!(path, "%PDF-1.4")

      assert {:error, :invalid_gzip_format} = FileValidator.validate_gzip(path)
    end

    test "returns error for ZIP file disguised as gzip", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "fake.tar.gz")
      # ZIP magic bytes (PK)
      File.write!(path, <<0x50, 0x4B, 0x03, 0x04>>)

      assert {:error, :invalid_gzip_format} = FileValidator.validate_gzip(path)
    end
  end

  describe "error_message/1" do
    test "returns message for invalid_gzip_format" do
      assert FileValidator.error_message(:invalid_gzip_format) ==
               "File is not a valid gzip archive. Please upload a .tar.gz file."
    end

    test "returns message for file_read_error" do
      assert FileValidator.error_message(:file_read_error) ==
               "Unable to read uploaded file. Please try again."
    end
  end
end
