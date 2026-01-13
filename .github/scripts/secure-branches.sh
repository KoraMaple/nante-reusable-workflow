#!/bin/bash
# Run this script to secure all branches and delete vulnerable refs

set -e

echo "🔒 Securing KoraMaple/nante-reusable-workflow"

# Delete vulnerable tags
echo "Deleting tags..."
git push --delete origin v0.1.0-alpha 2>/dev/null || echo "Tag v0.1.0-alpha doesn't exist"

# Delete release branch
echo "Deleting release/v0.1.0-alpha branch..."
git push --delete origin release/v0.1.0-alpha 2>/dev/null || echo "Branch doesn't exist"

# Delete old copilot branches
echo "Deleting old copilot branches..."
for branch in copilot/create-reusable-ci-workflow copilot/fix-terraform-availability copilot/implement-security-fixes copilot/pin-actions-to-commit-shas copilot/transition-to-github-hosted-runner copilot/update-runner-selection-logic; do
  git push --delete origin "$branch" 2>/dev/null || echo "Branch $branch doesn't exist"
done

echo "✓ Cleanup complete!"
echo ""
echo "⚠️ WARNING: Old commit SHAs with 'runs-on: self-hosted' still exist in Git history."
echo "The repository context validation added in this PR protects against this."
