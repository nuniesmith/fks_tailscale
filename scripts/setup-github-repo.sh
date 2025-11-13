#!/bin/bash
# Setup script to initialize GitHub repository for fks_tailscale

set -e

REPO_NAME="fks_tailscale"
GITHUB_USER="nuniesmith"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=========================================="
echo "Setting up GitHub repository: $REPO_NAME"
echo "=========================================="
echo ""

cd "$REPO_DIR"

# Check if git is initialized
if [ ! -d ".git" ]; then
    echo "Initializing git repository..."
    git init
    git branch -M main
fi

# Check if remote exists
if git remote get-url origin &>/dev/null; then
    echo "Remote 'origin' already exists:"
    git remote -v
    echo ""
    read -p "Update remote URL? (y/N) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git remote set-url origin "https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
        echo "✅ Remote URL updated"
    fi
else
    echo "Adding remote: https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
    git remote add origin "https://github.com/${GITHUB_USER}/${REPO_NAME}.git"
    echo "✅ Remote added"
fi

# Check if there are uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo ""
    echo "Uncommitted changes detected. Committing..."
    git add .
    git commit -m "feat: Initial Tailscale service setup with Kubernetes and Cloudflare DNS automation"
    echo "✅ Changes committed"
fi

# Show current status
echo ""
echo "Current git status:"
git status --short
echo ""

# Show remote info
echo "Remote configuration:"
git remote -v
echo ""

echo "=========================================="
echo "Next Steps:"
echo "=========================================="
echo ""
echo "1. Create repository on GitHub:"
echo "   https://github.com/new"
echo "   Name: $REPO_NAME"
echo "   Visibility: Private (recommended) or Public"
echo ""
echo "2. Push to GitHub:"
echo "   git push -u origin main"
echo ""
echo "3. Configure GitHub Secrets:"
echo "   Go to: https://github.com/${GITHUB_USER}/${REPO_NAME}/settings/secrets/actions"
echo "   Add secrets:"
echo "   - CLOUDFLARE_ZONE_ID"
echo "   - CLOUDFLARE_API_TOKEN"
echo "   - KUBECONFIG (optional)"
echo "   - TAILSCALE_API_KEY (optional)"
echo ""
echo "4. Deploy to Kubernetes:"
echo "   kubectl apply -f k8s/manifests/"
echo ""
echo "=========================================="

