# Tailscale Quick Start Guide

Get Tailscale running with Cloudflare DNS automation in 5 minutes!

## Prerequisites Checklist

- [ ] Tailscale account (https://tailscale.com)
- [ ] Cloudflare account with `fkstrading.xyz` domain
- [ ] Kubernetes cluster running
- [ ] kubectl configured

## Step 1: Get Tailscale Auth Key (2 minutes)

1. Go to https://login.tailscale.com/admin/settings/keys
2. Click "Generate auth key"
3. Check "Reusable"
4. Copy the key (starts with `tskey-auth-...`)

## Step 2: Create Kubernetes Secret (30 seconds)

```bash
kubectl create secret generic tailscale-auth \
  --from-literal=authkey='tskey-auth-...' \
  -n fks-trading
```

## Step 3: Deploy Tailscale (1 minute)

```bash
cd /home/jordan/Nextcloud/code/repos/fks/repo/tailscale
kubectl apply -f k8s/manifests/tailscale-rbac.yaml
kubectl apply -f k8s/manifests/tailscale-connector.yaml
```

Wait for pod to start:
```bash
kubectl wait --for=condition=ready pod -l app=tailscale-connector -n fks-trading --timeout=300s
```

## Step 4: Get Tailscale IP (30 seconds)

```bash
# Check pod logs for IP
kubectl logs -n fks-trading -l app=tailscale-connector | grep -i "100\."

# Or use script
./scripts/get-tailscale-ip.sh
```

The IP will be in `100.x.x.x` range.

## Step 5: Setup GitHub Repository (1 minute)

```bash
# Run setup script
./scripts/setup-github-repo.sh

# Create repo on GitHub, then push
git push -u origin main
```

## Step 6: Configure GitHub Secrets (1 minute)

Go to: https://github.com/nuniesmith/fks_tailscale/settings/secrets/actions

Add secrets:
- `CLOUDFLARE_ZONE_ID` - Get from Cloudflare dashboard
- `CLOUDFLARE_API_TOKEN` - Create at https://dash.cloudflare.com/profile/api-tokens

## Step 7: Test DNS Update

**Manual test:**
```bash
export CLOUDFLARE_ZONE_ID="your-zone-id"
export CLOUDFLARE_API_TOKEN="your-token"
TAILSCALE_IP=$(./scripts/get-tailscale-ip.sh)
./scripts/update-cloudflare-dns.sh $TAILSCALE_IP
```

**Via GitHub Actions:**
1. Go to Actions tab
2. Click "Update Cloudflare DNS"
3. Click "Run workflow"

## Verify

```bash
# Check DNS
dig fkstrading.xyz +short

# Should return your Tailscale IP (100.x.x.x)
```

## Troubleshooting

**Pod not starting?**
```bash
kubectl logs -n fks-trading -l app=tailscale-connector
```

**Can't get IP?**
- Check Tailscale admin console: https://login.tailscale.com/admin/machines
- Look for "fkstrading-xyz" device

**DNS not updating?**
- Check GitHub Actions logs
- Verify Cloudflare secrets are set correctly

## Next Steps

- ✅ Tailscale connected
- ✅ DNS automation configured
- ⏳ Monitor automatic updates (runs daily at 2 AM UTC)

**Done!** 🎉

For detailed information, see `docs/SETUP_GUIDE.md`

