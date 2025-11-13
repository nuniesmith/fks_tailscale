# Troubleshooting Guide

Common issues and solutions for the Tailscale DNS update workflow.

## Workflow Fails: "Could not determine Tailscale IP"

### Problem
The workflow can't find your Tailscale IP address.

### Solutions

#### Option 1: Add TAILSCALE_IP Secret (Easiest)

1. Get your Tailscale IP:
   - Go to https://login.tailscale.com/admin/machines
   - Find device "fkstrading-xyz"
   - Copy the IP (starts with `100.`)

2. Add to GitHub Secrets:
   - Go to: https://github.com/nuniesmith/fks_tailscale/settings/secrets/actions
   - Add secret: `TAILSCALE_IP` with your IP address
   - The workflow will use this if auto-detection fails

#### Option 2: Fix Tailscale API Key

1. Create Tailscale API key:
   - Go to: https://login.tailscale.com/admin/settings/keys
   - Create OAuth client or API key
   - Copy the key

2. Add to GitHub Secrets:
   - Add secret: `TAILSCALE_API_KEY` with your key

#### Option 3: Ensure Kubernetes Access

The workflow needs access to your Kubernetes cluster:

1. **If using KUBECONFIG secret:**
   - Export your kubeconfig: `cat ~/.kube/config | base64`
   - Add to GitHub Secrets as `KUBECONFIG`

2. **If using GitHub Actions with self-hosted runner:**
   - Ensure runner has kubectl configured
   - Ensure runner can access your cluster

#### Option 4: Check Tailscale Connector Pod

```bash
# Check if pod is running
kubectl get pods -n fks-trading -l app=tailscale-connector

# Check pod logs
kubectl logs -n fks-trading -l app=tailscale-connector

# Get IP from pod directly
kubectl exec -n fks-trading -l app=tailscale-connector -- tailscale status --json | jq -r '.Self.addresses[] | select(startswith("100."))'
```

## Workflow Fails: "Invalid API Token" (Cloudflare)

### Problem
Cloudflare API token is invalid or has wrong permissions.

### Solution

1. **Verify token permissions:**
   - Go to: https://dash.cloudflare.com/profile/api-tokens
   - Check token has:
     - Zone: DNS: Edit (for fkstrading.xyz)
     - Zone: Zone: Read (for fkstrading.xyz)

2. **Verify zone ID:**
   - Go to Cloudflare Dashboard
   - Select `fkstrading.xyz`
   - Copy Zone ID from API section
   - Verify it matches `CLOUDFLARE_ZONE_ID` secret

3. **Test token manually:**
   ```bash
   curl -X GET \
     "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=A&name=fkstrading.xyz" \
     -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
     -H "Content-Type: application/json"
   ```

## Workflow Runs But DNS Doesn't Update

### Check Workflow Logs

1. Go to: https://github.com/nuniesmith/fks_tailscale/actions
2. Click on the workflow run
3. Check each step for errors

### Common Issues

**IPs match (no update needed):**
- This is normal! If Tailscale IP matches DNS, no update is needed
- Check logs: "✅ IPs match, no update needed"

**DNS record not found:**
- Workflow will create a new record
- Check if creation succeeded in logs

**Permission denied:**
- Verify Cloudflare API token permissions
- Check token hasn't expired

## Manual DNS Update

If workflow isn't working, update DNS manually:

```bash
# Get Tailscale IP
TAILSCALE_IP=$(kubectl exec -n fks-trading -l app=tailscale-connector -- tailscale status --json | jq -r '.Self.addresses[] | select(startswith("100."))' | head -1)

# Update via script
export CLOUDFLARE_ZONE_ID="your-zone-id"
export CLOUDFLARE_API_TOKEN="your-token"
./scripts/update-cloudflare-dns.sh $TAILSCALE_IP
```

## Quick Fixes

### Skip Auto-Detection

Add `TAILSCALE_IP` secret with your current IP:
- Workflow will use this instead of trying to detect it

### Disable Workflow Temporarily

Edit `.github/workflows/update-dns.yml`:
- Comment out the schedule trigger
- Or add condition to skip: `if: false`

### Check All Secrets

Required secrets:
- ✅ `CLOUDFLARE_ZONE_ID`
- ✅ `CLOUDFLARE_API_TOKEN`
- ⚠️ `TAILSCALE_IP` (optional - for manual IP)
- ⚠️ `TAILSCALE_API_KEY` (optional - for API detection)
- ⚠️ `KUBECONFIG` (optional - for Kubernetes access)

## Still Having Issues?

1. Check workflow logs for specific error messages
2. Verify all secrets are set correctly
3. Test Cloudflare API token manually
4. Check Tailscale connector pod is running
5. Verify DNS record exists in Cloudflare

---

**For more help, see:** `docs/SETUP_GUIDE.md`

