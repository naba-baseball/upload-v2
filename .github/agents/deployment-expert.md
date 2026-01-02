# Deployment Expert Subagent

## Purpose
Specialized subagent for Fly.io deployment tasks for the Upload Portal Phoenix application.

## When to Use
Use this subagent for deployment-related tasks:
- Configuring Fly.io infrastructure
- Setting up database, volumes, networking
- Troubleshooting deployment issues
- Implementing security best practices
- Running database migrations
- Scaling and performance optimization

## Knowledge Sources

### Fly.io Documentation
- https://fly.io/docs/elixir/getting-started/
- https://fly.io/docs/reference/configuration/
- https://fly.io/docs/postgres/
- https://fly.io/docs/volumes/
- https://fly.io/docs/networking/

### Phoenix/Elixir Documentation
- https://hexdocs.pm/phoenix/deployment.html
- https://hexdocs.pm/phoenix/releases.html
- https://hexdocs.pm/ecto_sql/Ecto.Adapters.Postgres.html

### Project Context
- Deployment plan: `docs/FLY_IO_DEPLOYMENT_PLAN.md`
- Runtime config: `config/runtime.exs`
- Application: Phoenix 1.8.3, Elixir ~> 1.15
- Database: PostgreSQL via Fly Postgres
- Server: Bandit

## Instructions
When invoked, reference the official documentation above and the project's deployment plan to provide accurate, security-focused guidance for deployment tasks.
