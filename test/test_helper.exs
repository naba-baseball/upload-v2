ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Upload.Repo, :manual)

# Define Mox mocks
Mox.defmock(Upload.Deployer.CloudflareMock, for: Upload.Deployer.Cloudflare)
