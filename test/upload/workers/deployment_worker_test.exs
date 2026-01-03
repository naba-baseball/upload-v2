defmodule Upload.Workers.DeploymentWorkerTest do
  use Upload.DataCase

  import Upload.SitesFixtures

  alias Upload.Workers.DeploymentWorker
  alias Upload.Sites

  setup do
    # Ensure cloudflare config is empty so deploy fails with missing config
    original_config = Application.get_env(:upload, :cloudflare)
    Application.put_env(:upload, :cloudflare, [])

    on_exit(fn ->
      if original_config do
        Application.put_env(:upload, :cloudflare, original_config)
      else
        Application.delete_env(:upload, :cloudflare)
      end
    end)

    # Create a temporary tarball for testing
    tmp_dir = Path.join(System.tmp_dir!(), "worker_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)

    tarball_path = create_valid_tarball(tmp_dir)

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
    end)

    {:ok, tmp_dir: tmp_dir, tarball_path: tarball_path}
  end

  describe "perform/1 with valid args" do
    test "marks site as deploying before deployment", %{tarball_path: tarball_path} do
      site = site_fixture()
      Phoenix.PubSub.subscribe(Upload.PubSub, "site:#{site.id}")

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => tarball_path}}

      # Will fail due to missing cloudflare config, but should still mark as deploying first
      DeploymentWorker.perform(job)

      # Should have received a deploying update
      assert_received {:deployment_updated, %{deployment_status: "deploying"}}
    end

    test "returns {:cancel, :missing_cloudflare_config} when config is missing", %{
      tarball_path: tarball_path
    } do
      site = site_fixture()

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => tarball_path}}

      result = DeploymentWorker.perform(job)

      assert result == {:cancel, :missing_cloudflare_config}
    end

    test "marks site as failed when deployment fails", %{tarball_path: tarball_path} do
      site = site_fixture()

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => tarball_path}}

      DeploymentWorker.perform(job)

      updated_site = Sites.get_site!(site.id)
      assert updated_site.deployment_status == "failed"
      assert updated_site.last_deployment_error =~ "not configured"
    end

    test "cleans up tarball on non-retryable error", %{tarball_path: tarball_path} do
      site = site_fixture()

      assert File.exists?(tarball_path)

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => tarball_path}}

      DeploymentWorker.perform(job)

      refute File.exists?(tarball_path)
    end
  end

  describe "perform/1 with invalid args" do
    test "returns error when site_id is missing" do
      job = %Oban.Job{args: %{"tarball_path" => "/some/path"}}

      result = DeploymentWorker.perform(job)

      assert result == {:error, :invalid_args}
    end

    test "returns error when tarball_path is missing" do
      site = site_fixture()
      job = %Oban.Job{args: %{"site_id" => site.id}}

      result = DeploymentWorker.perform(job)

      assert result == {:error, :invalid_args}
    end

    test "returns error when args are empty" do
      job = %Oban.Job{args: %{}}

      result = DeploymentWorker.perform(job)

      assert result == {:error, :invalid_args}
    end
  end

  describe "perform/1 with extraction errors" do
    test "returns {:cancel, {:extraction_failed, _}} for invalid tarball" do
      site = site_fixture()

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => "/nonexistent/file.tar.gz"}}

      result = DeploymentWorker.perform(job)

      assert {:cancel, {:extraction_failed, _output}} = result
    end

    test "marks site as failed with extraction error message" do
      site = site_fixture()

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => "/nonexistent/file.tar.gz"}}

      DeploymentWorker.perform(job)

      updated_site = Sites.get_site!(site.id)
      assert updated_site.deployment_status == "failed"
      assert updated_site.last_deployment_error =~ "Failed to extract"
    end
  end

  describe "perform/1 with no valid files" do
    test "returns {:cancel, :no_valid_files} when tarball has no valid files", %{tmp_dir: tmp_dir} do
      site = site_fixture()

      # Create a tarball with only invalid file types
      tarball_path = create_tarball_with_invalid_files(tmp_dir)

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => tarball_path}}

      result = DeploymentWorker.perform(job)

      assert result == {:cancel, :no_valid_files}
    end

    test "cleans up tarball when no valid files", %{tmp_dir: tmp_dir} do
      site = site_fixture()
      tarball_path = create_tarball_with_invalid_files(tmp_dir)

      assert File.exists?(tarball_path)

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => tarball_path}}

      DeploymentWorker.perform(job)

      refute File.exists?(tarball_path)
    end
  end

  # Helper functions

  defp create_valid_tarball(tmp_dir) do
    source_dir = Path.join(tmp_dir, "source_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(source_dir)

    File.write!(Path.join(source_dir, "index.html"), "<html><body>Hello</body></html>")
    File.write!(Path.join(source_dir, "style.css"), "body { color: red; }")

    tarball_path = Path.join(tmp_dir, "valid_#{:erlang.unique_integer([:positive])}.tar.gz")

    {_, 0} = System.cmd("tar", ["-czf", tarball_path, "-C", source_dir, "."])

    tarball_path
  end

  defp create_tarball_with_invalid_files(tmp_dir) do
    source_dir = Path.join(tmp_dir, "invalid_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(source_dir)

    # Only create files that are not in the allowed extensions list
    File.write!(Path.join(source_dir, "readme.doc"), "Some doc content")
    File.write!(Path.join(source_dir, "data.xlsx"), "Some excel content")

    tarball_path = Path.join(tmp_dir, "invalid_#{:erlang.unique_integer([:positive])}.tar.gz")

    {_, 0} = System.cmd("tar", ["-czf", tarball_path, "-C", source_dir, "."])

    tarball_path
  end
end
