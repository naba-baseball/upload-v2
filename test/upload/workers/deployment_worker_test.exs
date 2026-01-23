defmodule Upload.Workers.DeploymentWorkerTest do
  use Upload.DataCase

  import Upload.SitesFixtures

  alias Upload.Workers.DeploymentWorker
  alias Upload.Sites

  setup do
    # Create a temporary tarball for testing
    tmp_dir = Path.join(System.tmp_dir!(), "worker_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)

    tarball_path = create_valid_tarball(tmp_dir)

    on_exit(fn ->
      File.rm_rf!(tmp_dir)
      # Clean up any deployed sites
      priv_sites_dir = Path.join([:code.priv_dir(:upload), "static", "sites"])
      File.rm_rf!(priv_sites_dir)
      File.mkdir_p!(priv_sites_dir)
    end)

    {:ok, tmp_dir: tmp_dir, tarball_path: tarball_path}
  end

  describe "perform/1 with valid tarball" do
    test "extracts tarball to site directory", %{tarball_path: tarball_path} do
      site = site_fixture()

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => tarball_path}}

      DeploymentWorker.perform(job)

      site_dir = Path.join([:code.priv_dir(:upload), "static", "sites", site.subdomain])
      assert File.exists?(Path.join(site_dir, "index.html"))
      assert File.exists?(Path.join(site_dir, "style.css"))
    end

    test "marks site as deploying before extraction", %{tarball_path: tarball_path} do
      site = site_fixture()
      Phoenix.PubSub.subscribe(Upload.PubSub, "site:#{site.id}")

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => tarball_path}}

      DeploymentWorker.perform(job)

      # Should have received a deploying update
      assert_received {:deployment_updated, %{deployment_status: "deploying"}}
    end

    test "marks site as deployed on success", %{tarball_path: tarball_path} do
      site = site_fixture()

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => tarball_path}}

      result = DeploymentWorker.perform(job)

      assert result == :ok
      updated_site = Sites.get_site!(site.id)
      assert updated_site.deployment_status == "deployed"
      assert updated_site.last_deployed_at != nil
      assert updated_site.last_deployment_error == nil
    end

    test "cleans up tarball after successful deployment", %{tarball_path: tarball_path} do
      site = site_fixture()

      assert File.exists?(tarball_path)

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => tarball_path}}

      DeploymentWorker.perform(job)

      refute File.exists?(tarball_path)
    end

    test "cleans up existing site directory before extraction", %{tmp_dir: tmp_dir} do
      site = site_fixture()
      site_dir = Path.join([:code.priv_dir(:upload), "static", "sites", site.subdomain])

      # Create existing site directory with old file
      File.mkdir_p!(site_dir)
      old_file = Path.join(site_dir, "old_file.txt")
      File.write!(old_file, "old content")

      tarball_path = create_valid_tarball(tmp_dir)
      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => tarball_path}}

      DeploymentWorker.perform(job)

      # Old file should be gone
      refute File.exists?(old_file)
      # New files should exist
      assert File.exists?(Path.join(site_dir, "index.html"))
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
    test "returns {:cancel, {:file_stat_failed, _}} for non-existent tarball" do
      site = site_fixture()

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => "/nonexistent/file.tar.gz"}}

      result = DeploymentWorker.perform(job)

      assert {:cancel, {:file_stat_failed, :enoent}} = result
    end

    test "marks site as failed with file read error message" do
      site = site_fixture()

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => "/nonexistent/file.tar.gz"}}

      DeploymentWorker.perform(job)

      updated_site = Sites.get_site!(site.id)
      assert updated_site.deployment_status == "failed"
      assert updated_site.last_deployment_error =~ "Failed to read archive file"
    end

    test "cleans up tarball even on extraction failure", %{tmp_dir: tmp_dir} do
      site = site_fixture()

      # Create invalid tarball
      tarball_path = Path.join(tmp_dir, "invalid.tar.gz")
      File.write!(tarball_path, "not a valid gzip file")

      assert File.exists?(tarball_path)

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => tarball_path}}

      DeploymentWorker.perform(job)

      refute File.exists?(tarball_path)
    end

    test "cleans up partial extraction on failure", %{tmp_dir: tmp_dir} do
      site = site_fixture()
      site_dir = Path.join([:code.priv_dir(:upload), "static", "sites", site.subdomain])

      # Create invalid tarball (no HTML files)
      tarball_path = create_tarball_with_no_html(tmp_dir)

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => tarball_path}}

      DeploymentWorker.perform(job)

      # Site directory should not exist after failed deployment
      refute File.exists?(site_dir)
    end
  end

  describe "perform/1 with no HTML files" do
    test "returns {:cancel, :no_html_files} when tarball has no HTML files", %{tmp_dir: tmp_dir} do
      site = site_fixture()

      tarball_path = create_tarball_with_no_html(tmp_dir)

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => tarball_path}}

      result = DeploymentWorker.perform(job)

      assert result == {:cancel, :no_html_files}
    end

    test "marks site as failed with appropriate error message", %{tmp_dir: tmp_dir} do
      site = site_fixture()
      tarball_path = create_tarball_with_no_html(tmp_dir)

      job = %Oban.Job{args: %{"site_id" => site.id, "tarball_path" => tarball_path}}

      DeploymentWorker.perform(job)

      updated_site = Sites.get_site!(site.id)
      assert updated_site.deployment_status == "failed"
      assert updated_site.last_deployment_error =~ "must contain at least one HTML file"
    end

    test "cleans up tarball when no HTML files", %{tmp_dir: tmp_dir} do
      site = site_fixture()
      tarball_path = create_tarball_with_no_html(tmp_dir)

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

  defp create_tarball_with_no_html(tmp_dir) do
    source_dir = Path.join(tmp_dir, "no_html_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(source_dir)

    # Only create non-HTML files
    File.write!(Path.join(source_dir, "style.css"), "body { color: red; }")
    File.write!(Path.join(source_dir, "script.js"), "console.log('hi');")

    tarball_path = Path.join(tmp_dir, "no_html_#{:erlang.unique_integer([:positive])}.tar.gz")

    {_, 0} = System.cmd("tar", ["-czf", tarball_path, "-C", source_dir, "."])

    tarball_path
  end
end
