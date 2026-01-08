import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :upload, Upload.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "upload_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :upload, UploadWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "D6XpSL37L9zzuCKcoDqDrmiteunmVhQhKX+7mizXP6NBr6MBTLoINjs3gy5pU9PF",
  server: false

# In test we don't send emails
config :upload, Upload.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Disable Oban job processing in tests
config :upload, Oban, testing: :inline

# Use mock for Cloudflare deployer in tests
config :upload, :cloudflare_deployer, Upload.Deployer.CloudflareMock

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
