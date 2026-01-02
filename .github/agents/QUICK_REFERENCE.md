# Deployment Expert Agent - Quick Reference

## Quick Start

Need help with Fly.io deployment? Use the deployment-expert agent!

```
📍 Configuration: .github/agents/deployment-expert.md
📖 Full Docs: docs/FLY_IO_DEPLOYMENT_PLAN.md
```

## When to Use

✅ **Use the deployment-expert agent for**:
- Deployment configuration questions
- Infrastructure setup (database, volumes, networking)
- Security hardening and best practices
- Troubleshooting deployment issues
- Performance optimization
- Database migrations and operations
- Health checks and monitoring setup

❌ **Don't use for**:
- Application code logic
- Business logic questions
- UI/UX concerns
- Non-deployment tasks

## Common Questions

### Configuration

**Q**: How do I configure SSL for PostgreSQL?
```elixir
# Reference: https://fly.io/docs/postgres/
# See: docs/FLY_IO_DEPLOYMENT_PLAN.md Section: Database Security

config :upload, Upload.Repo,
  ssl: true,
  ssl_opts: [
    verify: :verify_peer,
    cacerts: :public_key.cacerts_get()
  ]
```

**Q**: What should my fly.toml look like?
```
See: docs/FLY_IO_DEPLOYMENT_PLAN.md Section: Phase 3, Step 1
Reference: https://fly.io/docs/reference/configuration/
```

**Q**: How do I set up health checks?
```
See: docs/FLY_IO_DEPLOYMENT_PLAN.md Section: Phase 3, Step 4
Reference: https://fly.io/docs/reference/configuration/#the-http_service-section
```

### Secrets Management

**Q**: How do I set production secrets?
```bash
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
fly secrets set ENCRYPTION_SALT=$(mix phx.gen.secret)
fly secrets set PHX_HOST=your-app.fly.dev
```

**Q**: How do I verify secrets are set?
```bash
fly secrets list
```

### Database Operations

**Q**: How do I run migrations?
```bash
fly ssh console -C "/app/bin/migrate"
```

**Q**: How do I connect to the database?
```bash
fly postgres connect -a upload-db
```

**Q**: How do I create a database backup?
```bash
fly postgres backup create -a upload-db
```

### Deployment Operations

**Q**: How do I deploy?
```bash
fly deploy
```

**Q**: How do I rollback?
```bash
fly releases
fly releases rollback <version>
```

**Q**: How do I scale?
```bash
# Scale instances
fly scale count 2

# Scale memory
fly scale memory 1024
```

### Troubleshooting

**Q**: How do I view logs?
```bash
# Real-time logs
fly logs

# Specific instance
fly logs -i <instance-id>
```

**Q**: How do I SSH into the app?
```bash
fly ssh console
```

**Q**: How do I check app status?
```bash
fly status
```

**Q**: Deployment failed, what do I check?
1. Check logs: `fly logs`
2. Verify health endpoint: `curl https://your-app.fly.dev/health`
3. Check database connectivity: `fly postgres status -a upload-db`
4. Verify secrets: `fly secrets list`
5. Check fly.toml configuration

## Key Documentation Links

### Fly.io
- [Elixir Getting Started](https://fly.io/docs/elixir/getting-started/)
- [Configuration Reference](https://fly.io/docs/reference/configuration/)
- [Postgres Docs](https://fly.io/docs/postgres/)
- [Volumes](https://fly.io/docs/volumes/)
- [Troubleshooting](https://fly.io/docs/getting-started/troubleshooting/)

### Phoenix/Elixir
- [Phoenix Deployment](https://hexdocs.pm/phoenix/deployment.html)
- [Mix Releases](https://hexdocs.pm/mix/Mix.Tasks.Release.html)
- [Phoenix Security](https://hexdocs.pm/phoenix/security_best_practices.html)
- [Ecto Production](https://hexdocs.pm/ecto_sql/Ecto.Adapters.Postgres.html#module-production-configuration)

### Project Specific
- [Deployment Plan](../docs/FLY_IO_DEPLOYMENT_PLAN.md)
- [Issue Template](../ISSUE_TEMPLATE/flyio-deployment.md)

## Security Checklist

Before going live, verify:
- [ ] `SECRET_KEY_BASE` set (64+ characters)
- [ ] `ENCRYPTION_SALT` set
- [ ] Database SSL enabled with peer verification
- [ ] HTTPS enforced (`force_ssl: true`)
- [ ] HSTS headers configured
- [ ] CSP headers configured
- [ ] File upload size limits enforced
- [ ] Health check endpoint responding
- [ ] Database backups configured
- [ ] Monitoring and alerts active
- [ ] No secrets in git repository

## Phase-by-Phase Reference

### Phase 1: Prerequisites
```bash
# Install Fly.io CLI
curl -L https://fly.io/install.sh | sh

# Authenticate
fly auth login

# Verify local build
mix test
```

### Phase 2: Infrastructure
```bash
# Initialize app
fly launch --no-deploy

# Create database
fly postgres create --name upload-db
fly postgres attach upload-db

# Create volume
fly volumes create upload_data --size 10 --region <region>
```

### Phase 3: Configuration
- [ ] Create Dockerfile (see deployment plan)
- [ ] Create fly.toml (see deployment plan)
- [ ] Add /health endpoint
- [ ] Create migration scripts
- [ ] Configure security headers

### Phase 4: Security
```bash
# Set all secrets
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
fly secrets set ENCRYPTION_SALT=$(mix phx.gen.secret)
fly secrets set PHX_HOST=your-app.fly.dev
```

### Phase 5: Deploy
```bash
# Deploy
fly deploy

# Run migrations
fly ssh console -C "/app/bin/migrate"

# Verify
fly status
fly logs
curl https://your-app.fly.dev/health
```

### Phase 6: Post-Deployment
- [ ] Configure monitoring
- [ ] Set up backups
- [ ] Test restoration
- [ ] Document procedures

## Emergency Contacts

- **Fly.io Community**: https://community.fly.io
- **Phoenix Forum**: https://elixirforum.com
- **Deployment Plan**: docs/FLY_IO_DEPLOYMENT_PLAN.md
- **Agent Config**: .github/agents/deployment-expert.md

## Pro Tips

1. **Always test locally first**: Build Docker image locally before deploying
   ```bash
   docker build -t upload-test .
   docker run -p 8080:8080 upload-test
   ```

2. **Use fly.toml versioning**: Commit fly.toml to git for version control

3. **Monitor during deployment**: Keep `fly logs` running in another terminal

4. **Test health checks**: Ensure `/health` endpoint works before deploying

5. **Backup before major changes**: Create database backup before risky operations

6. **Use staging environment**: Test changes in staging before production

---

**Quick Access**:
- 📖 Full deployment plan: `docs/FLY_IO_DEPLOYMENT_PLAN.md`
- 🤖 Agent details: `.github/agents/deployment-expert.md`
- 🎫 Create issue: `.github/ISSUE_TEMPLATE/flyio-deployment.md`
