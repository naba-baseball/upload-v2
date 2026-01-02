# Instructions: Create GitHub Issue for Fly.io Deployment

The Fly.io deployment plan has been created and committed to the repository. To track the deployment, please create a GitHub issue using one of the methods below.

## Method 1: Using GitHub Web Interface (Recommended)

1. Visit: https://github.com/naba-baseball/upload-v2/issues/new/choose
2. Select the template: **"Fly.io Deployment Plan"**
3. The template will auto-populate with all the details
4. Click "Submit new issue"

## Method 2: Using GitHub CLI

If you have `gh` CLI installed:

```bash
cd /home/user/upload-v2
./scripts/create_deployment_issue.sh
```

Or manually:

```bash
gh issue create \
  --title "Deploy Upload Portal to Fly.io - Comprehensive Security-Focused Plan" \
  --label "deployment,infrastructure,security,documentation" \
  --body-file .github/ISSUE_TEMPLATE/flyio-deployment.md
```

## Method 3: Using GitHub API

If you have a GitHub Personal Access Token:

```bash
export GITHUB_TOKEN="your_token_here"

curl -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/naba-baseball/upload-v2/issues \
  -d @- << 'EOF'
{
  "title": "Deploy Upload Portal to Fly.io - Comprehensive Security-Focused Plan",
  "body": "$(cat .github/ISSUE_TEMPLATE/flyio-deployment.md)",
  "labels": ["deployment", "infrastructure", "security", "documentation"]
}
EOF
```

## What's Included

The deployment plan includes:

- ✅ **Comprehensive Documentation**: `docs/FLY_IO_DEPLOYMENT_PLAN.md` (30+ pages)
- ✅ **Issue Template**: `.github/ISSUE_TEMPLATE/flyio-deployment.md`
- ✅ **Helper Script**: `scripts/create_deployment_issue.sh`
- ✅ **Security Best Practices**: OWASP-aligned security measures
- ✅ **Step-by-Step Guide**: From prerequisites to post-deployment
- ✅ **Cost Analysis**: ~$3-10/month for current usage
- ✅ **Rollback Procedures**: Disaster recovery plan
- ✅ **Monitoring Setup**: Health checks and alerting

## Quick Links

- **Deployment Plan**: [docs/FLY_IO_DEPLOYMENT_PLAN.md](docs/FLY_IO_DEPLOYMENT_PLAN.md)
- **Issue Template**: [.github/ISSUE_TEMPLATE/flyio-deployment.md](.github/ISSUE_TEMPLATE/flyio-deployment.md)
- **Repository**: https://github.com/naba-baseball/upload-v2
- **Branch**: `claude/plan-flyio-deployment-ka3HK`

## Next Steps After Creating the Issue

1. Review the complete deployment plan in `docs/FLY_IO_DEPLOYMENT_PLAN.md`
2. Answer the questions in the issue (domain, email, upload limits, etc.)
3. Follow the implementation phases systematically
4. Check off items as you complete them
5. Ask questions in the issue comments

---

**Note**: The deployment plan has been pushed to branch `claude/plan-flyio-deployment-ka3HK`. You can merge this branch or create a PR to bring these files into your main branch.
