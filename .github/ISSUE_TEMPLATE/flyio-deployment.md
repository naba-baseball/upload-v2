---
name: Fly.io Deployment Plan
about: Deploy Upload Portal to Fly.io with security best practices
title: 'Deploy Upload Portal to Fly.io - Comprehensive Security-Focused Plan'
labels: 'deployment, infrastructure, security, documentation'
assignees: ''
---

## Overview

This issue tracks the deployment of the Upload Portal application to Fly.io with a focus on security best practices and operational excellence.

## Documentation

A comprehensive deployment plan has been created and committed to the repository:
**[docs/FLY_IO_DEPLOYMENT_PLAN.md](../../docs/FLY_IO_DEPLOYMENT_PLAN.md)**

## Executive Summary

The plan covers:
- Complete infrastructure setup on Fly.io
- Security hardening following OWASP best practices
- Database configuration with PostgreSQL
- File storage with persistent volumes
- Monitoring and alerting
- Backup and disaster recovery
- Cost optimization (~$3-10/month for current usage)

## Key Security Measures

### Infrastructure Security
- ✅ Encrypted secrets management via Fly.io
- ✅ SSL/TLS for all connections (app and database)
- ✅ Private networking between services
- ✅ Non-root Docker containers
- ✅ Minimal port exposure (80, 443 only)

### Application Security
- ✅ HTTPS enforcement with HSTS headers
- ✅ Content Security Policy (CSP)
- 🔲 File upload validation (size, type, content)
- 🔲 Input sanitization and validation
- 🔲 Rate limiting on upload endpoints
- 🔲 Secure session management

### Database Security
- ✅ SSL/TLS with peer verification
- ✅ Private networking (no public access)
- ✅ Automated daily backups
- ✅ Strong password generation
- ✅ Connection pooling limits

### Operational Security
- 🔲 Regular dependency updates
- 🔲 Vulnerability scanning (`mix hex.audit`)
- 🔲 Health check monitoring
- ✅ Automated deployment rollback capability
- ✅ Incident response procedures

## Implementation Phases

### Phase 1: Prerequisites ⏳
- [ ] Install Fly.io CLI
- [ ] Authenticate with Fly.io
- [ ] Verify local build (`mix test`)

### Phase 2: Infrastructure Setup 📦
- [ ] Initialize Fly.io app (`fly launch --no-deploy`)
- [ ] Create PostgreSQL database (`fly postgres create`)
- [ ] Create persistent volume for uploads
- [ ] Configure networking

### Phase 3: Application Configuration 🔧
- [ ] Create Dockerfile with security best practices
- [ ] Configure `fly.toml`
- [ ] Add `/health` endpoint
- [ ] Implement migration scripts
- [ ] Configure security headers

### Phase 4: Security Hardening 🔒
- [ ] Generate `SECRET_KEY_BASE` (64+ chars)
- [ ] Generate `ENCRYPTION_SALT`
- [ ] Enable database SSL with peer verification
- [ ] Configure CSP headers
- [ ] Implement file upload size limits
- [ ] Add file type validation (only .tar.gz)
- [ ] Enable rate limiting
- [ ] Configure HSTS headers
- [ ] Audit codebase for hardcoded secrets

### Phase 5: Deployment 🚀
- [ ] Set production secrets in Fly.io
- [ ] Deploy application (`fly deploy`)
- [ ] Run database migrations
- [ ] Verify SSL/TLS configuration
- [ ] Test file upload functionality
- [ ] Verify health endpoint responds

### Phase 6: Post-Deployment 📊
- [ ] Configure monitoring and alerts
- [ ] Set up automated backup schedule
- [ ] Test backup restoration procedure
- [ ] Configure log retention
- [ ] Document operational procedures
- [ ] Create incident response runbook
- [ ] Train team on deployment workflows

### Phase 7: Ongoing Maintenance 🔄
- [ ] Schedule weekly log reviews
- [ ] Schedule monthly security audits (`mix hex.audit`)
- [ ] Schedule quarterly dependency updates
- [ ] Test disaster recovery procedures
- [ ] Review and update documentation

## Critical Security Checklist

**Must Complete Before Going Live:**
- [ ] No secrets in git repository
- [ ] `SECRET_KEY_BASE` set (64+ characters)
- [ ] `ENCRYPTION_SALT` set
- [ ] Database SSL enabled with peer verification
- [ ] HTTPS enforced (force_ssl: true)
- [ ] HSTS headers configured
- [ ] CSP headers configured
- [ ] File upload size limits enforced
- [ ] File type validation (only .tar.gz)
- [ ] Health check endpoint responding
- [ ] Database backups configured and tested
- [ ] Monitoring and alerts active

## Resource Requirements

**Estimated Monthly Costs (3-6 users):**
| Component | Specs | Cost |
|-----------|-------|------|
| App Instances (1-2) | shared-cpu-1x, 512MB | $3-6 |
| PostgreSQL | shared-cpu-1x, 256MB | $0-3 |
| Volume | 10GB | $0.15 |
| Bandwidth | ~10GB | Free |
| **Total** | | **~$3-10** |

**Compute Resources:**
- 1-2 app instances
- 512MB RAM per instance
- 1 shared CPU per instance
- 10GB persistent volume

## Success Criteria

Application must meet all of the following:
- [ ] Accessible via HTTPS with valid certificate
- [ ] Health check endpoint returns 200 OK
- [ ] Users can successfully upload .tar.gz files
- [ ] Files persist across deployments
- [ ] Database migrations run successfully
- [ ] All security headers present in responses
- [ ] No secrets committed to git
- [ ] Monitoring dashboards show healthy metrics
- [ ] Backups created automatically
- [ ] Rollback procedure tested and documented

## Architecture Diagram

```
┌─────────────────────────────────────────────┐
│         Fly.io Global Network (Anycast)     │
│              SSL/TLS Termination            │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│           Load Balancer (Fly Proxy)         │
└──────────────────┬──────────────────────────┘
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
┌─────────────┐       ┌─────────────┐
│   App VM 1  │       │   App VM 2  │
│  (Phoenix)  │       │  (Phoenix)  │
│   512MB RAM │       │   512MB RAM │
└──────┬──────┘       └──────┬──────┘
       │                     │
       └──────────┬──────────┘
                  │ Private Network (6PN)
                  ▼
         ┌─────────────────┐
         │   PostgreSQL    │
         │   (Fly.io)      │
         │   SSL/TLS       │
         └─────────────────┘
                  │
                  ▼
         ┌─────────────────┐
         │  Persistent     │
         │  Volume (10GB)  │
         │  (Uploads)      │
         └─────────────────┘
```

## Questions for Discussion

Before proceeding, please answer:

1. **Domain**: What domain name should the app use? (defaults to `*.fly.dev`)
2. **Email**: Do we need email notifications? Which provider? (Mailgun suggested)
3. **Upload Limits**: What is the maximum file size for uploads? (suggest 100MB)
4. **Retention**: Should old files be auto-deleted? After how many days?
5. **Regions**: Single region deployment sufficient, or need multi-region?
6. **Monitoring**: Use Fly.io built-in monitoring, or integrate external service?

## Documentation References

- 📖 [Complete Deployment Plan](../../docs/FLY_IO_DEPLOYMENT_PLAN.md)
- 🚀 [Fly.io Phoenix Guide](https://fly.io/docs/elixir/getting-started/)
- 🔒 [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- 🛡️ [Fly.io Security](https://fly.io/docs/reference/security/)

## Rollback Plan

If deployment fails or issues arise:

```bash
# View recent releases
fly releases

# Rollback to previous version
fly releases rollback <version-number>

# Check application status
fly status

# View logs
fly logs
```

**Estimated Recovery Time:** 5-15 minutes

## Next Steps

1. Review the complete deployment plan in `docs/FLY_IO_DEPLOYMENT_PLAN.md`
2. Answer the questions above
3. Begin Phase 1 (Prerequisites)
4. Follow the checklist systematically
5. Update this issue as each phase completes

---

**Priority:** High
**Complexity:** Medium
**Estimated Time:** 4-6 hours (initial deployment + testing)
**Assigned To:** _To be assigned_
