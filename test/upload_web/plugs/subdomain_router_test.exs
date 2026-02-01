defmodule UploadWeb.Plugs.SubdomainRouterTest do
  use UploadWeb.ConnCase
  alias Upload.Sites
  alias UploadWeb.Plugs.SubdomainRouter

  setup do
    # Create test sites with different routing modes
    {:ok, subdomain_site} =
      Sites.create_site(%{
        name: "Subdomain Site",
        subdomain: "subtest",
        routing_mode: "subdomain"
      })

    {:ok, subpath_site} =
      Sites.create_site(%{
        name: "Subpath Site",
        subdomain: "pathtest",
        routing_mode: "subpath"
      })

    {:ok, both_site} =
      Sites.create_site(%{
        name: "Both Site",
        subdomain: "bothtest",
        routing_mode: "both"
      })

    # Mark sites as deployed
    Sites.mark_deployed(subdomain_site)
    Sites.mark_deployed(subpath_site)
    Sites.mark_deployed(both_site)

    # Create site directories and index.html files
    for site <- [subdomain_site, subpath_site, both_site] do
      site_dir = Sites.site_dir(site)
      File.mkdir_p!(site_dir)
      File.write!(Path.join(site_dir, "index.html"), "<h1>#{site.name}</h1>")
    end

    on_exit(fn ->
      # Clean up site directories
      for site <- [subdomain_site, subpath_site, both_site] do
        File.rm_rf!(Sites.site_dir(site))
      end
    end)

    %{
      subdomain_site: subdomain_site,
      subpath_site: subpath_site,
      both_site: both_site
    }
  end

  # Helper function to call the SubdomainRouter plug directly
  defp call_subdomain_router(conn) do
    SubdomainRouter.call(conn, [])
  end

  describe "subdomain routing" do
    test "serves site when mode is subdomain", %{subdomain_site: _site} do
      conn =
        build_conn()
        |> Map.put(:host, "subtest.localhost")
        |> Map.put(:request_path, "/")
        |> call_subdomain_router()

      assert conn.status == 200
      assert conn.resp_body =~ "Subdomain Site"
    end

    test "does not serve via subpath when mode is subdomain", %{subdomain_site: _site} do
      conn =
        build_conn()
        |> Map.put(:host, "localhost")
        |> Map.put(:request_path, "/sites/subtest/")
        |> call_subdomain_router()

      # Should pass through to normal routing (not halted)
      refute conn.halted
    end
  end

  describe "subpath routing" do
    test "serves site when mode is subpath", %{subpath_site: _site} do
      conn =
        build_conn()
        |> Map.put(:host, "localhost")
        |> Map.put(:request_path, "/sites/pathtest/")
        |> call_subdomain_router()

      assert conn.status == 200
      assert conn.resp_body =~ "Subpath Site"
    end

    test "does not serve via subdomain when mode is subpath", %{subpath_site: _site} do
      conn =
        build_conn()
        |> Map.put(:host, "pathtest.localhost")
        |> Map.put(:request_path, "/")
        |> call_subdomain_router()

      # Should pass through to normal routing (not halted)
      refute conn.halted
    end
  end

  describe "both routing mode" do
    test "serves site via subdomain", %{both_site: _site} do
      conn =
        build_conn()
        |> Map.put(:host, "bothtest.localhost")
        |> Map.put(:request_path, "/")
        |> call_subdomain_router()

      assert conn.status == 200
      assert conn.resp_body =~ "Both Site"
    end

    test "serves site via subpath", %{both_site: _site} do
      conn =
        build_conn()
        |> Map.put(:host, "localhost")
        |> Map.put(:request_path, "/sites/bothtest/")
        |> call_subdomain_router()

      assert conn.status == 200
      assert conn.resp_body =~ "Both Site"
    end
  end

  describe "path normalization" do
    test "strips subpath prefix correctly", %{both_site: site} do
      # Create a nested file
      site_dir = Sites.site_dir(site)
      File.write!(Path.join(site_dir, "about.html"), "<h1>About</h1>")

      conn =
        build_conn()
        |> Map.put(:host, "localhost")
        |> Map.put(:request_path, "/sites/bothtest/about.html")
        |> call_subdomain_router()

      assert conn.status == 200
      assert conn.resp_body =~ "About"
    end

    test "handles root path via subpath", %{both_site: _site} do
      conn =
        build_conn()
        |> Map.put(:host, "localhost")
        |> Map.put(:request_path, "/sites/bothtest")
        |> call_subdomain_router()

      assert conn.status == 200
      assert conn.resp_body =~ "Both Site"
    end
  end

  describe "security" do
    test "rejects invalid subdomain format in subpath", %{both_site: _site} do
      conn =
        build_conn()
        |> Map.put(:host, "localhost")
        |> Map.put(:request_path, "/sites/invalid_subdomain/")
        |> call_subdomain_router()

      # Should pass through (invalid format, not halted)
      refute conn.halted
    end

    test "only serves deployed sites" do
      {:ok, pending_site} =
        Sites.create_site(%{
          name: "Pending Site",
          subdomain: "pending",
          routing_mode: "both"
        })

      # Create directory but don't mark as deployed
      site_dir = Sites.site_dir(pending_site)
      File.mkdir_p!(site_dir)
      File.write!(Path.join(site_dir, "index.html"), "<h1>Pending</h1>")

      # Try subdomain
      conn =
        build_conn()
        |> Map.put(:host, "pending.localhost")
        |> Map.put(:request_path, "/")
        |> call_subdomain_router()

      refute conn.halted

      # Try subpath
      conn =
        build_conn()
        |> Map.put(:host, "localhost")
        |> Map.put(:request_path, "/sites/pending/")
        |> call_subdomain_router()

      refute conn.halted

      # Clean up
      File.rm_rf!(site_dir)
    end
  end
end
