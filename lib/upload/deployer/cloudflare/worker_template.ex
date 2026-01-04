defmodule Upload.Deployer.Cloudflare.WorkerTemplate do
  @moduledoc """
  Provides the minimal Worker JavaScript template for serving static assets.

  The Worker simply proxies all requests to the ASSETS binding, which serves
  the uploaded static files. No custom logic is needed.
  """

  @doc """
  Returns the minimal worker.js content for serving static assets.

  The worker uses the ASSETS binding provided by Cloudflare Workers
  Static Assets to serve files uploaded during deployment.
  """
  def worker_js do
    """
    export default {
      async fetch(request, env) {
        return env.ASSETS.fetch(request);
      }
    };
    """
  end

  @doc """
  Returns the worker metadata for deployment.

  The metadata specifies the main module, compatibility date, and assets JWT.
  """
  def metadata(completion_jwt) do
    %{
      main_module: "worker.js",
      compatibility_date: Date.utc_today() |> Date.to_iso8601(),
      assets: %{jwt: completion_jwt}
    }
  end
end
