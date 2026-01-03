defmodule Upload.Deployer.CloudflareTest do
  use ExUnit.Case, async: true

  alias Upload.Deployer.Cloudflare

  setup do
    tmp_dir =
      Path.join(System.tmp_dir!(), "cloudflare_test_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir}
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
      assert {:error, {:extraction_failed, _}} =
               Cloudflare.extract_tarball("/non/existent/file.tar.gz")
    end

    test "returns error for path traversal attempts", %{tmp_dir: tmp_dir} do
      # Create a tarball with path traversal attempt
      tarball_path = create_malicious_tarball(tmp_dir)

      assert {:error, {:path_traversal_detected, _}} = Cloudflare.extract_tarball(tarball_path)
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

  # Helper to create a tarball with path traversal
  defp create_malicious_tarball(tmp_dir) do
    source_dir = Path.join(tmp_dir, "malicious_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(source_dir)

    # Create a file with path traversal in the name
    # We use a symbolic link to simulate path traversal since tar will follow it
    malicious_dir = Path.join(source_dir, "subdir")
    File.mkdir_p!(malicious_dir)

    # Create an actual traversal by making the tarball manually with absolute paths
    # For testing, we create a file and then modify the tarball
    File.write!(Path.join(malicious_dir, "safe.txt"), "safe content")

    tarball_path = Path.join(tmp_dir, "malicious_#{:erlang.unique_integer([:positive])}.tar.gz")

    # Create initial tarball
    {_, 0} = System.cmd("tar", ["-czf", tarball_path, "-C", source_dir, "."])

    # For a real path traversal test, we need to craft a tarball with "../" in paths
    # This is complex to do programmatically, so we'll create a simpler test
    # by creating a tarball with a symlink that points outside

    # Actually, let's create a proper test - make a tarball with ../ in path
    traversal_dir = Path.join(tmp_dir, "traversal_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(traversal_dir, "normal"))
    File.write!(Path.join(traversal_dir, "normal/file.txt"), "content")

    # Create the tarball with transform to inject ../
    traversal_tarball =
      Path.join(tmp_dir, "traversal_#{:erlang.unique_integer([:positive])}.tar.gz")

    # Use GNU tar's --transform or fall back to creating manually
    # On macOS, we need to use a different approach
    case System.cmd("tar", ["--version"], stderr_to_stdout: true) do
      {output, _} when is_binary(output) ->
        if String.contains?(output, "GNU") do
          # GNU tar - use transform
          {_, 0} =
            System.cmd("tar", [
              "-czf",
              traversal_tarball,
              "-C",
              traversal_dir,
              "--transform",
              "s|normal|../escape|",
              "."
            ])
        else
          # BSD tar (macOS) - create files with literal ../ in name (which tar will reject on extract)
          # This is tricky - for now create with symlink approach
          File.mkdir_p!(Path.join(traversal_dir, "..\\escape"))
          File.write!(Path.join(traversal_dir, "..\\escape/bad.txt"), "bad content")
          {_, 0} = System.cmd("tar", ["-czf", traversal_tarball, "-C", traversal_dir, "."])
        end
    end

    traversal_tarball
  end
end
