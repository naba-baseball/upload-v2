#!/bin/bash
# Script to create GitHub issue for Fly.io deployment plan

set -e

echo "Creating GitHub issue for Fly.io deployment plan..."
echo ""

# Check if gh CLI is available
if command -v gh &> /dev/null; then
    echo "✓ GitHub CLI found, creating issue..."

    gh issue create \
        --title "Deploy Upload Portal to Fly.io - Comprehensive Security-Focused Plan" \
        --label "deployment,infrastructure,security,documentation" \
        --body-file .github/ISSUE_TEMPLATE/flyio-deployment.md

    echo ""
    echo "✓ Issue created successfully!"
    echo "View the issue on GitHub to track deployment progress."
else
    echo "⚠ GitHub CLI (gh) not found."
    echo ""
    echo "Please install GitHub CLI or create the issue manually:"
    echo ""
    echo "1. Go to: https://github.com/naba-baseball/upload-v2/issues/new"
    echo "2. Use the template: 'Fly.io Deployment Plan'"
    echo "3. Or manually copy from: .github/ISSUE_TEMPLATE/flyio-deployment.md"
    echo ""
    echo "Alternatively, install GitHub CLI:"
    echo "  https://cli.github.com/"
fi
