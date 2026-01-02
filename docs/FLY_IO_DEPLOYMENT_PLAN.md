# Fly.io Deployment Plan for Upload Portal

## Executive Summary

This document outlines a comprehensive, security-focused deployment strategy for the Upload Portal application to Fly.io. The plan covers infrastructure setup, security hardening, operational procedures, and monitoring.

## Application Overview

- **Technology Stack**: Phoenix 1.8.3, Elixir ~> 1.15, PostgreSQL
- **Web Server**: Bandit
- **Primary Function**: Portal for uploading .tar.gz files for static site deployment
- **User Base**: 3-6 users (small, trusted group)
- **Current Usage**: File exchange via Discord

## Deployment Architecture

### Infrastructure Components

1. **Application Instances**
   - Phoenix application running on Fly.io machines
   - Bandit web server handling HTTP/HTTPS requests
   - Horizontal scaling capability

2. **Database**
   - Fly Postgres cluster
   - Automated backups
   - Connection pooling via Ecto

3. **Storage**
   - Fly.io volumes for persistent file storage
   - Separate volume for uploaded .tar.gz files

4. **Networking**
   - Fly.io's global Anycast network
   - Automatic SSL/TLS certificate management
   - Private networking between app and database

## Security Best Practices

### 1. Secrets Management

**Environment Variables (Never commit to git):**
- `SECRET_KEY_BASE` - Phoenix secret (generate with `mix phx.gen.secret`)
- `DATABASE_URL` - PostgreSQL connection string
- `ENCRYPTION_SALT` - Additional encryption salt (generate with `mix phx.gen.secret`)
- `PHX_HOST` - Production hostname
- `MAILGUN_API_KEY` / `MAILGUN_DOMAIN` (if using email)

**Implementation:**
```bash
# Set secrets using Fly.io secrets (encrypted at rest)
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
fly secrets set DATABASE_URL=postgres://user:pass@host/db
fly secrets set ENCRYPTION_SALT=$(mix phx.gen.secret)
fly secrets set PHX_HOST=your-app.fly.dev
```

### 2. Database Security

- **Connection Security**:
  - Use SSL/TLS for all database connections
  - Enable `ssl: true` in Ecto configuration
  - Use Fly.io private networking (6PN) for app-to-database communication

- **Access Control**:
  - Strong password for database user (generated via `fly postgres create`)
  - Restrict database access to application instances only
  - No public internet access to database

- **Backup Strategy**:
  - Enable automatic daily backups via Fly Postgres
  - Test restore procedures monthly
  - Retain backups for 7+ days

### 3. Application Security

- **HTTPS/TLS**:
  - Force SSL in production (`force_ssl: [rewrite_on: [:x_forwarded_proto]]`)
  - Enable HSTS headers (already configured in `config/prod.exs`)
  - Automatic certificate management via Fly.io

- **File Upload Security**:
  - Implement file size limits (prevent DoS via large uploads)
  - Validate file types (only accept .tar.gz)
  - Scan uploaded files for malicious content
  - Store uploads outside web-accessible directory
  - Use Content Security Policy (CSP) headers

- **Authentication & Authorization**:
  - Implement proper user authentication before allowing uploads
  - Role-based access control (Admin vs. regular users)
  - Rate limiting on upload endpoints
  - Session security (secure, httponly cookies)

- **Input Validation**:
  - Validate all user inputs server-side
  - Sanitize file names to prevent path traversal
  - Validate webhook URLs before making requests

### 4. Network Security

- **Firewall Rules**:
  - Only expose ports 80 (redirects to 443) and 443
  - Use Fly.io's private networking for internal services

- **DDoS Protection**:
  - Leverage Fly.io's built-in DDoS protection
  - Implement rate limiting at application level
  - Use connection limits in Bandit configuration

### 5. Dependency Security

- **Regular Updates**:
  - Keep Elixir, Erlang, and all dependencies updated
  - Subscribe to security advisories for Phoenix and dependencies
  - Use `mix hex.audit` to check for vulnerable dependencies
  - Automated dependency updates via Dependabot

- **Supply Chain Security**:
  - Verify package checksums
  - Use `mix.lock` for reproducible builds
  - Review dependency changes before updating

## Deployment Steps

### Phase 1: Prerequisites

1. **Install Fly.io CLI**:
   ```bash
   curl -L https://fly.io/install.sh | sh
   ```

2. **Authenticate**:
   ```bash
   fly auth login
   ```

3. **Verify Application**:
   ```bash
   mix deps.get
   mix compile
   mix test
   ```

### Phase 2: Fly.io Configuration

1. **Initialize Fly.io App**:
   ```bash
   fly launch --no-deploy
   ```
   - Choose a unique app name
   - Select region (closest to users)
   - Decline database creation (we'll create it separately)

2. **Create PostgreSQL Database**:
   ```bash
   fly postgres create --name upload-db
   fly postgres attach upload-db
   ```
   This automatically sets `DATABASE_URL` secret.

3. **Create Persistent Volume** (for file uploads):
   ```bash
   fly volumes create upload_data --size 10 --region <your-region>
   ```

### Phase 3: Configuration Files

1. **Create/Update `fly.toml`**:
   ```toml
   app = "your-app-name"
   primary_region = "iad"  # Or your chosen region

   [build]
     [build.args]
       ELIXIR_VERSION = "1.15"
       OTP_VERSION = "26"

   [env]
     PHX_SERVER = "true"
     PORT = "8080"
     POOL_SIZE = "10"
     ECTO_IPV6 = "true"

   [[mounts]]
     source = "upload_data"
     destination = "/app/uploads"

   [http_service]
     internal_port = 8080
     force_https = true
     auto_stop_machines = false
     auto_start_machines = true
     min_machines_running = 1
     processes = ["app"]

   [[http_service.checks]]
     grace_period = "10s"
     interval = "30s"
     method = "GET"
     timeout = "5s"
     path = "/health"

   [[vm]]
     memory = "512mb"
     cpu_kind = "shared"
     cpus = 1
   ```

2. **Create Dockerfile**:
   ```dockerfile
   # Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian
   # instead of Alpine to avoid DNS issues in production.
   ARG ELIXIR_VERSION=1.15.7
   ARG OTP_VERSION=26.2.2
   ARG DEBIAN_VERSION=bookworm-20231009-slim

   ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
   ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}"

   FROM ${BUILDER_IMAGE} as builder

   # Install build dependencies
   RUN apt-get update -y && apt-get install -y build-essential git \
       && apt-get clean && rm -f /var/lib/apt/lists/*_*

   # Prepare build directory
   WORKDIR /app

   # Install hex + rebar
   RUN mix local.hex --force && \
       mix local.rebar --force

   # Set build ENV
   ENV MIX_ENV="prod"

   # Install mix dependencies
   COPY mix.exs mix.lock ./
   RUN mix deps.get --only $MIX_ENV
   RUN mkdir config

   # Copy compile-time config files before we compile dependencies
   COPY config/config.exs config/${MIX_ENV}.exs config/
   RUN mix deps.compile

   # Copy application code
   COPY priv priv
   COPY lib lib
   COPY assets assets

   # Compile assets
   RUN mix assets.deploy

   # Compile the release
   RUN mix compile

   # Changes to config/runtime.exs don't require recompiling the code
   COPY config/runtime.exs config/

   # Create release
   COPY rel rel
   RUN mix release

   # Start a new build stage - runner
   FROM ${RUNNER_IMAGE}

   # Install runtime dependencies
   RUN apt-get update -y && \
       apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
       && apt-get clean && rm -f /var/lib/apt/lists/*_*

   # Set the locale
   RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

   ENV LANG en_US.UTF-8
   ENV LANGUAGE en_US:en
   ENV LC_ALL en_US.UTF-8

   WORKDIR "/app"

   # Create non-root user
   RUN groupadd -r upload && useradd -r -g upload upload

   # Create upload directory with proper permissions
   RUN mkdir -p /app/uploads && chown -R upload:upload /app/uploads

   # Set runner ENV
   ENV MIX_ENV="prod"

   # Copy built application
   COPY --from=builder --chown=upload:upload /app/_build/${MIX_ENV}/rel/upload ./

   # Switch to non-root user
   USER upload

   # Expose port
   EXPOSE 8080

   # Start the application
   CMD ["/app/bin/server"]
   ```

3. **Create `.dockerignore`**:
   ```
   .git/
   .gitignore
   .env
   .env.*
   _build/
   deps/
   node_modules/
   assets/node_modules/
   priv/static/
   *.log
   .DS_Store
   .elixir_ls/
   ```

4. **Create Health Check Endpoint** (`lib/upload_web/controllers/health_controller.ex`):
   ```elixir
   defmodule UploadWeb.HealthController do
     use UploadWeb, :controller

     def index(conn, _params) do
       # Check database connectivity
       case Upload.Repo.query("SELECT 1") do
         {:ok, _} ->
           conn
           |> put_status(:ok)
           |> json(%{status: "healthy", timestamp: DateTime.utc_now()})

         {:error, _} ->
           conn
           |> put_status(:service_unavailable)
           |> json(%{status: "unhealthy", reason: "database_unavailable"})
       end
     end
   end
   ```

   Add to router (`lib/upload_web/router.ex`):
   ```elixir
   scope "/", UploadWeb do
     pipe_through :api
     get "/health", HealthController, :index
   end
   ```

### Phase 4: Security Configuration

1. **Set all secrets**:
   ```bash
   fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
   fly secrets set ENCRYPTION_SALT=$(mix phx.gen.secret)
   fly secrets set PHX_HOST=your-app.fly.dev
   ```

2. **Enable SSL in database config** (`config/runtime.exs`):
   ```elixir
   config :upload, Upload.Repo,
     ssl: true,
     ssl_opts: [
       verify: :verify_peer,
       cacerts: :public_key.cacerts_get()
     ],
     url: database_url,
     pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
     socket_options: maybe_ipv6
   ```

3. **Add security headers** (in endpoint.ex):
   ```elixir
   plug :put_secure_browser_headers, %{
     "content-security-policy" => "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'",
     "x-frame-options" => "DENY",
     "x-content-type-options" => "nosniff",
     "referrer-policy" => "strict-origin-when-cross-origin",
     "permissions-policy" => "geolocation=(), microphone=(), camera=()"
   }
   ```

### Phase 5: Database Migration

1. **Create release script** (`rel/overlays/bin/migrate`):
   ```bash
   #!/bin/sh
   set -eu

   cd -P -- "$(dirname -- "$0")"
   exec ./upload eval Upload.Release.migrate
   ```

2. **Create migration module** (`lib/upload/release.ex`):
   ```elixir
   defmodule Upload.Release do
     @moduledoc """
     Used for executing DB release tasks when run in production without Mix installed.
     """
     @app :upload

     def migrate do
       load_app()

       for repo <- repos() do
         {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
       end
     end

     def rollback(repo, version) do
       load_app()
       {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
     end

     defp repos do
       Application.fetch_env!(@app, :ecto_repos)
     end

     defp load_app do
       Application.load(@app)
     end
   end
   ```

3. **Run migrations**:
   ```bash
   fly ssh console -C "/app/bin/migrate"
   ```

### Phase 6: Initial Deployment

1. **Deploy application**:
   ```bash
   fly deploy
   ```

2. **Verify deployment**:
   ```bash
   fly status
   fly logs
   curl https://your-app.fly.dev/health
   ```

3. **Scale if needed**:
   ```bash
   # Scale to 2 instances for high availability
   fly scale count 2

   # Scale memory if needed
   fly scale memory 1024
   ```

## Post-Deployment Configuration

### 1. Monitoring & Observability

- **Fly.io Monitoring**:
  - Enable built-in metrics dashboard
  - Set up log forwarding to external service (optional)
  - Configure alerts for:
    - High error rates
    - Memory usage > 80%
    - CPU usage > 80%
    - Database connection failures

- **Application Monitoring**:
  - Use Phoenix LiveDashboard (already configured)
  - Access via `/dashboard` (protect with authentication)
  - Monitor Ecto connection pool usage

- **Log Management**:
  ```bash
  # View real-time logs
  fly logs

  # View specific instance logs
  fly logs -i <instance-id>
  ```

### 2. Backup & Recovery

- **Database Backups**:
  ```bash
  # Create manual backup
  fly postgres backup create -a upload-db

  # List backups
  fly postgres backup list -a upload-db

  # Restore from backup
  fly postgres backup restore -a upload-db <backup-id>
  ```

- **File Storage Backups**:
  - Set up regular volume snapshots
  - Consider S3/R2 for long-term storage
  - Test restore procedures

### 3. Disaster Recovery Plan

1. **Database Failure**:
   - Restore from latest Postgres backup
   - Estimated RTO: 15 minutes

2. **Application Failure**:
   - Automatic restart by Fly.io
   - Manual redeploy if needed: `fly deploy`
   - Estimated RTO: 5 minutes

3. **Volume Loss**:
   - Restore from volume snapshots
   - Users may need to re-upload recent files
   - Estimated RTO: 30 minutes

### 4. Scaling Strategy

**Current Scale (3-6 users):**
- 1-2 instances
- 512MB RAM per instance
- 1 shared CPU per instance

**Growth Triggers:**
- > 10 concurrent users: Scale to 2 instances
- > 50 concurrent users: Scale to 3 instances + 1GB RAM
- Database slow queries: Add read replica

**Autoscaling Configuration**:
```toml
[http_service]
  auto_stop_machines = false
  auto_start_machines = true
  min_machines_running = 1

  [[http_service.concurrency]]
    type = "requests"
    hard_limit = 1000
    soft_limit = 800
```

## Operational Procedures

### Deploying Updates

```bash
# 1. Test locally
mix test

# 2. Create release
git tag -a v1.0.1 -m "Release v1.0.1"
git push origin v1.0.1

# 3. Deploy
fly deploy

# 4. Run migrations if needed
fly ssh console -C "/app/bin/migrate"

# 5. Verify
fly logs
curl https://your-app.fly.dev/health
```

### Rolling Back Deployment

```bash
# List recent releases
fly releases

# Rollback to specific version
fly releases rollback <version>
```

### Accessing Production Console

```bash
# SSH into application
fly ssh console

# Open IEx console
fly ssh console -C "/app/bin/upload remote"
```

### Database Maintenance

```bash
# Connect to database
fly postgres connect -a upload-db

# View connection stats
fly postgres db list -a upload-db

# Scale database
fly postgres update -a upload-db --vm-size shared-cpu-2x
```

## Cost Optimization

### Current Estimate (Small deployment):
- **App instances**: 1-2 × shared-cpu-1x @ 512MB ≈ $3-6/month
- **Postgres**: shared-cpu-1x @ 256MB ≈ $0-3/month (included in free tier)
- **Volume**: 10GB ≈ $0.15/month
- **Bandwidth**: ~10GB ≈ Free (160GB free tier)

**Total**: ~$3-10/month

### Optimization Tips:
- Use auto_stop_machines for dev/staging
- Monitor and right-size volumes
- Use Fly.io free tier ($5/month credit)
- Optimize asset delivery (CDN for static assets)

## Security Maintenance

### Regular Tasks

**Weekly:**
- Review application logs for anomalies
- Check error rates in monitoring dashboard

**Monthly:**
- Update dependencies (`mix deps.update --all`)
- Run security audit (`mix hex.audit`)
- Review access logs for unauthorized access
- Test backup restoration

**Quarterly:**
- Rotate `SECRET_KEY_BASE` (requires careful planning)
- Review and update security headers
- Penetration testing (if applicable)
- Review user access and permissions

### Security Incident Response

1. **Detect**: Monitor logs and alerts
2. **Assess**: Determine scope and impact
3. **Contain**: Isolate affected systems
4. **Remediate**: Apply fixes, rotate secrets
5. **Recover**: Restore from clean backups
6. **Review**: Post-mortem and improvements

## Compliance Considerations

- **Data Privacy**: Implement GDPR/privacy controls if handling EU users
- **Data Retention**: Define retention policy for uploaded files
- **Audit Logging**: Log all administrative actions
- **Encryption**: At rest (Fly.io volumes encrypted), in transit (TLS)

## Migration Checklist

- [ ] Install Fly.io CLI
- [ ] Create Fly.io account and authenticate
- [ ] Run `fly launch --no-deploy`
- [ ] Create PostgreSQL database
- [ ] Create persistent volume
- [ ] Create Dockerfile and .dockerignore
- [ ] Create fly.toml configuration
- [ ] Add health check endpoint
- [ ] Set all production secrets
- [ ] Enable database SSL
- [ ] Add security headers
- [ ] Create migration scripts
- [ ] Test build locally with `docker build`
- [ ] Deploy with `fly deploy`
- [ ] Run database migrations
- [ ] Verify health endpoint
- [ ] Configure monitoring and alerts
- [ ] Test file upload functionality
- [ ] Set up backup schedule
- [ ] Document rollback procedure
- [ ] Create runbook for common issues
- [ ] Train team on deployment procedures

## Additional Resources

- [Fly.io Phoenix Guide](https://fly.io/docs/elixir/getting-started/)
- [Phoenix Deployment Guide](https://hexdocs.pm/phoenix/deployment.html)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Fly.io Security Best Practices](https://fly.io/docs/reference/security/)

## Support and Troubleshooting

### Common Issues

1. **Database Connection Errors**:
   - Verify `DATABASE_URL` is set correctly
   - Check SSL configuration
   - Ensure database is running: `fly postgres status -a upload-db`

2. **File Upload Failures**:
   - Verify volume is mounted correctly
   - Check file size limits
   - Review disk space: `fly ssh console -C "df -h"`

3. **Performance Issues**:
   - Check memory usage: `fly status`
   - Review Ecto pool size
   - Consider scaling up instances

4. **SSL/TLS Errors**:
   - Verify `force_ssl` configuration
   - Check certificate status: `fly certs list`
   - Ensure `PHX_HOST` matches actual domain

### Getting Help

- Fly.io Community: https://community.fly.io
- Phoenix Forum: https://elixirforum.com
- Emergency: `fly doctor` for diagnostics

---

**Document Version**: 1.0
**Last Updated**: 2026-01-02
**Maintained By**: Development Team
