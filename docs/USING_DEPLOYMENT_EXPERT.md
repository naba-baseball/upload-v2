# Using the Deployment Expert Agent

## Overview

The **deployment-expert agent** is an AI assistant configuration designed to help with Fly.io deployment tasks for the Upload Portal Phoenix application. It has specialized knowledge of Fly.io, Phoenix, and Elixir deployment best practices.

## What is it?

The deployment-expert agent is a documented configuration that guides AI assistants (like Claude) to:
- Reference official Fly.io and Phoenix documentation
- Apply deployment best practices
- Provide accurate, documentation-backed answers
- Follow security best practices
- Help troubleshoot deployment issues

## When to Use

Use the deployment-expert agent for:

✅ **Infrastructure Questions**
- "How do I set up a PostgreSQL database on Fly.io?"
- "What's the best way to configure persistent volumes?"
- "How do I set up private networking?"

✅ **Configuration Help**
- "What should my fly.toml look like for a Phoenix app?"
- "How do I configure SSL for my database connection?"
- "What Docker configuration is optimal for Elixir?"

✅ **Security Guidance**
- "What security headers should I add?"
- "How do I configure SSL/TLS properly?"
- "What secrets do I need to set?"

✅ **Troubleshooting**
- "My deployment failed, how do I debug it?"
- "The health check is failing, what should I check?"
- "Database connections are timing out, why?"

✅ **Operations**
- "How do I run database migrations in production?"
- "What's the best rollback strategy?"
- "How do I scale my application?"

## How to Use

### Method 1: Direct Reference (with AI Assistant)

When asking a deployment question to an AI assistant (like Claude Code):

```
"I need help configuring PostgreSQL SSL on Fly.io.
Please reference the deployment-expert agent configuration
at .github/agents/deployment-expert.md for this task."
```

### Method 2: Context Sharing

Share the agent configuration with your AI assistant:

```
"I'm working on Fly.io deployment for the Upload Portal.
Please read .github/agents/deployment-expert.md and help me
with the following question: [your question]"
```

### Method 3: Quick Reference

For quick lookups, use the cheat sheet:

```
See: .github/agents/QUICK_REFERENCE.md
```

## Example Interactions

### Example 1: Database SSL Configuration

**You**: "How do I configure SSL for my PostgreSQL connection on Fly.io? Use the deployment-expert agent."

**Agent Response** (paraphrased):
```
Based on the Fly.io Postgres documentation and Phoenix deployment guides:

1. In config/runtime.exs, configure SSL:

config :upload, Upload.Repo,
  ssl: true,
  ssl_opts: [
    verify: :verify_peer,
    cacerts: :public_key.cacerts_get()
  ],
  url: database_url,
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

2. This enables SSL with peer verification using system CA certificates.

3. Fly.io Postgres provides SSL by default on private networks.

Reference:
- https://fly.io/docs/postgres/
- https://hexdocs.pm/ecto_sql/Ecto.Adapters.Postgres.html
```

### Example 2: Health Check Setup

**You**: "What's the best way to implement health checks? Reference deployment-expert."

**Agent Response** (paraphrased):
```
Based on Fly.io health check documentation and Phoenix best practices:

1. Create a health controller (lib/upload_web/controllers/health_controller.ex):

defmodule UploadWeb.HealthController do
  use UploadWeb, :controller

  def index(conn, _params) do
    case Upload.Repo.query("SELECT 1") do
      {:ok, _} ->
        json(conn, %{status: "healthy"})
      {:error, _} ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "unhealthy"})
    end
  end
end

2. Add route in router.ex:
get "/health", HealthController, :index

3. Configure in fly.toml:
[[http_service.checks]]
  grace_period = "10s"
  interval = "30s"
  method = "GET"
  timeout = "5s"
  path = "/health"

Reference:
- https://fly.io/docs/reference/configuration/#the-http_service-section
- See: docs/FLY_IO_DEPLOYMENT_PLAN.md Section: Phase 3, Step 4
```

### Example 3: Troubleshooting Failed Deployment

**You**: "My deployment is failing with a timeout. Use deployment-expert to help debug."

**Agent Response** (paraphrased):
```
Based on Fly.io troubleshooting guide, let's check:

1. View recent logs:
   fly logs

2. Check application status:
   fly status

3. Common timeout causes:
   - Health check failing (check /health endpoint)
   - Database not accessible (verify DATABASE_URL)
   - Missing secrets (verify with: fly secrets list)
   - Startup taking too long (check grace_period in fly.toml)

4. Debug steps:
   a. Test health endpoint locally
   b. Verify database connectivity
   c. Check fly.toml health check configuration
   d. Review application logs for startup errors

5. Increase grace_period if app needs more startup time:
   [[http_service.checks]]
     grace_period = "30s"  # Increase from 10s

Reference:
- https://fly.io/docs/getting-started/troubleshooting/
- docs/FLY_IO_DEPLOYMENT_PLAN.md Section: Troubleshooting
```

## What the Agent Knows

The deployment-expert agent references:

### Official Documentation
- ✅ Fly.io Elixir guides (all sections)
- ✅ Fly.io configuration reference
- ✅ Fly.io Postgres documentation
- ✅ Phoenix deployment guide
- ✅ Elixir releases documentation
- ✅ Ecto production configuration
- ✅ Security best practices (OWASP)

### Project-Specific
- ✅ Upload Portal deployment plan (docs/FLY_IO_DEPLOYMENT_PLAN.md)
- ✅ Application configuration (config/runtime.exs, config/prod.exs)
- ✅ Project dependencies (mix.exs)
- ✅ Current deployment status

### Best Practices
- ✅ Security hardening techniques
- ✅ Performance optimization
- ✅ Monitoring and alerting
- ✅ Disaster recovery
- ✅ Cost optimization

## Benefits

Using the deployment-expert agent provides:

1. **Accurate Information**: Responses based on official documentation
2. **Best Practices**: Security and performance best practices included
3. **Consistency**: Standardized approaches across deployments
4. **Time Saving**: Quick answers without manual doc searching
5. **Learning**: Explanations include documentation references
6. **Project Awareness**: Understands your specific setup

## Quick Reference

Keep these handy:

- **Full Agent Config**: `.github/agents/deployment-expert.md`
- **Quick Reference**: `.github/agents/QUICK_REFERENCE.md`
- **Deployment Plan**: `docs/FLY_IO_DEPLOYMENT_PLAN.md`
- **Issue Template**: `.github/ISSUE_TEMPLATE/flyio-deployment.md`

## Tips for Best Results

1. **Be Specific**: Ask specific questions rather than broad ones
2. **Provide Context**: Mention what you've already tried
3. **Include Errors**: Share error messages or logs when troubleshooting
4. **Reference Files**: Point to relevant config files when asking questions
5. **Follow Up**: Ask clarifying questions if needed

## Example Questions to Ask

**Configuration:**
- "How do I configure fly.toml for horizontal scaling?"
- "What environment variables do I need to set?"
- "How do I set up multi-region deployment?"

**Security:**
- "What security headers should I configure?"
- "How do I rotate secrets safely?"
- "What SSL/TLS settings should I use?"

**Operations:**
- "How do I perform zero-downtime deployments?"
- "What's the best backup strategy?"
- "How do I monitor application health?"

**Troubleshooting:**
- "Why is my database connection failing?"
- "How do I debug high memory usage?"
- "Why are my health checks timing out?"

## Related Documentation

- [Deployment Plan](FLY_IO_DEPLOYMENT_PLAN.md) - Complete deployment guide
- [Agent Directory](.github/agents/README.md) - Overview of all agents
- [Quick Reference](.github/agents/QUICK_REFERENCE.md) - Fast lookup guide

## Feedback and Improvements

If you find documentation gaps or have suggestions:
1. Update `.github/agents/deployment-expert.md`
2. Add to `.github/agents/QUICK_REFERENCE.md`
3. Update this guide
4. Commit changes to help future deployments

---

**Remember**: The deployment-expert agent is a tool to help you access authoritative information quickly. Always verify critical configurations and test thoroughly before deploying to production.
