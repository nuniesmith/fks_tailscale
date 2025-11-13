# Tailscale Setup Guide

Complete guide for setting up Tailscale with Kubernetes and Cloudflare DNS automation.

## Prerequisites

1. **Tailscale Account**
   - Sign up at https://tailscale.com
   - Create a reusable auth key at https://login.tailscale.com/admin/settings/keys

2. **Cloudflare Account**
   - Domain `fkstrading.xyz` must be in Cloudflare
   - Create API token with DNS edit permissions

3. **Kubernetes Cluster**
   - Minikube, k3s, or any Kubernetes cluster
   - kubectl configured and working

## Step 1: Create Tailscale Auth Key

1. Go to https://login.tailscale.com/admin/settings/keys
2. Click "Generate auth key"
3. Check "Reusable" and "Ephemeral" (optional)
4. Copy the key (starts with `tskey-auth-...`)
5. Save it securely - you'll need it for the Kubernetes secret

## Step 2: Create Kubernetes Secret

```bash
kubectl create secret generic tailscale-auth \
  --from-literal=authkey='tskey-auth-...' \
  -n fks-trading
```

**Verify:**
```bash
kubectl get secret tailscale-auth -n fks-trading
```

## Step 3: Deploy Tailscale Connector

```bash
# Apply RBAC first
kubectl apply -f k8s/manifests/tailscale-rbac.yaml

# Deploy Tailscale connector
kubectl apply -f k8s/manifests/tailscale-connector.yaml

# Check status
kubectl get pods -n fks-trading -l app=tailscale-connector
kubectl logs -n fks-trading -l app=tailscale-connector
```

**Wait for pod to be ready:**
```bash
kubectl wait --for=condition=ready pod -l app=tailscale-connector -n fks-trading --timeout=300s
```

## Step 4: Get Tailscale IP

Once the pod is running, get the Tailscale IP:

```bash
# Method 1: From pod logs
kubectl logs -n fks-trading -l app=tailscale-connector | grep -i "100\."

# Method 2: Using script
./scripts/get-tailscale-ip.sh

# Method 3: Check Tailscale admin console
# Go to https://login.tailscale.com/admin/machines
# Find "fkstrading-xyz" and note the IP
```

The IP will be in the `100.x.x.x` range (Tailscale's IP space).

## Step 5: Configure Cloudflare Secrets

### Get Cloudflare Zone ID

1. Go to Cloudflare Dashboard
2. Select domain `fkstrading.xyz`
3. Scroll down to "API" section
4. Copy "Zone ID"

### Create Cloudflare API Token

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click "Create Token"
3. Use "Edit zone DNS" template
4. Set permissions:
   - Zone: DNS:Edit
   - Zone Resources: Include - Specific zone - fkstrading.xyz
5. Copy the token

### Add to GitHub Secrets

1. Go to https://github.com/nuniesmith/fks_tailscale/settings/secrets/actions
2. Add secrets:
   - `CLOUDFLARE_ZONE_ID` - Your zone ID
   - `CLOUDFLARE_API_TOKEN` - Your API token
   - `KUBECONFIG` (optional) - Base64 encoded kubeconfig for GitHub Actions
   - `TAILSCALE_API_KEY` (optional) - For direct API access

## Step 6: Test DNS Update

### Manual Update

```bash
# Set environment variables
export CLOUDFLARE_ZONE_ID="your-zone-id"
export CLOUDFLARE_API_TOKEN="your-api-token"

# Get Tailscale IP
TAILSCALE_IP=$(./scripts/get-tailscale-ip.sh)

# Update DNS
./scripts/update-cloudflare-dns.sh $TAILSCALE_IP
```

### Via GitHub Actions

1. Push to main/master branch
2. Workflow will automatically:
   - Get Tailscale IP
   - Check current DNS record
   - Update if different

Or trigger manually:
1. Go to Actions tab
2. Select "Update Cloudflare DNS" workflow
3. Click "Run workflow"
4. Optionally check "Force update"

## Step 7: Verify DNS

```bash
# Check DNS record
dig fkstrading.xyz +short

# Should return your Tailscale IP (100.x.x.x)
```

## Troubleshooting

### Tailscale Pod Not Starting

**Check logs:**
```bash
kubectl logs -n fks-trading -l app=tailscale-connector
```

**Common issues:**
- Auth key invalid → Regenerate and update secret
- Network permissions → Check RBAC and security context
- HostPath not available → Ensure `/dev/net/tun` exists on node

**Fix auth key:**
```bash
kubectl delete secret tailscale-auth -n fks-trading
kubectl create secret generic tailscale-auth \
  --from-literal=authkey='new-key' \
  -n fks-trading
kubectl delete pod -n fks-trading -l app=tailscale-connector
```

### Can't Get Tailscale IP

**Try multiple methods:**
```bash
# Method 1: Kubernetes
kubectl get svc tailscale-connector -n fks-trading

# Method 2: DNS
dig fkstrading-xyz.tailscale.ts.net

# Method 3: Tailscale admin console
# https://login.tailscale.com/admin/machines
```

### DNS Not Updating

**Check GitHub Actions logs:**
1. Go to Actions tab
2. Click on failed workflow
3. Check error messages

**Common issues:**
- Invalid API token → Regenerate token
- Wrong zone ID → Verify in Cloudflare dashboard
- IP already matches → This is normal, no update needed

**Test API manually:**
```bash
curl -X GET \
  "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=A&name=fkstrading.xyz" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  -H "Content-Type: application/json" | jq '.'
```

## Automation

### Scheduled Updates

The workflow runs daily at 2 AM UTC to check and update DNS if needed.

To change schedule, edit `.github/workflows/update-dns.yml`:
```yaml
schedule:
  - cron: '0 2 * * *'  # Change to your preferred time
```

### Webhook Trigger (Advanced)

You can set up a webhook to trigger updates when Tailscale IP changes:

1. Create webhook endpoint
2. Configure Tailscale to call webhook on IP change
3. Webhook triggers GitHub Actions workflow

## Security Best Practices

1. ✅ Use reusable auth keys (not one-time)
2. ✅ Store secrets in Kubernetes secrets (not in code)
3. ✅ Use Cloudflare API tokens (not global API key)
4. ✅ Limit API token permissions (DNS edit only)
5. ✅ Use RBAC to limit pod permissions
6. ✅ Enable network policies (optional)

## Monitoring

### Check Tailscale Status

```bash
# Pod status
kubectl get pods -n fks-trading -l app=tailscale-connector

# Logs
kubectl logs -n fks-trading -l app=tailscale-connector --tail=50

# Health check
kubectl exec -n fks-trading -it deployment/tailscale-connector -- tailscale status
```

### Check DNS Record

```bash
# Current DNS
dig fkstrading.xyz +short

# Cloudflare API
curl -s -X GET \
  "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?type=A&name=fkstrading.xyz" \
  -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
  | jq '.result[0]'
```

## Next Steps

1. ✅ Tailscale connector deployed
2. ✅ DNS automation configured
3. ⏳ Monitor first automatic update
4. ⏳ Verify DNS propagation
5. ⏳ Test connectivity via Tailscale IP

---

**Setup complete!** 🎉

