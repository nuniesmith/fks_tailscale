# FKS Tailscale Service

Tailscale integration for Kubernetes to provide secure network access and dynamic DNS updates.

## Overview

This service provides:
- ✅ Tailscale connector for Kubernetes
- ✅ Automatic Cloudflare DNS updates when Tailscale IP changes
- ✅ GitHub Actions workflow for DNS management
- ✅ Kubernetes manifests for Tailscale deployment

## Features

- **Tailscale Connector**: Connects Kubernetes cluster to Tailscale network
- **Dynamic DNS**: Automatically updates Cloudflare DNS when Tailscale IP changes
- **GitHub Actions**: Workflow to update DNS records via Cloudflare API
- **Kubernetes Integration**: Native Kubernetes deployment with proper RBAC

## Quick Start

### 1. Prerequisites

- Tailscale account and auth key
- Cloudflare account with API token
- Kubernetes cluster (minikube, k3s, etc.)

### 2. Setup Tailscale Auth Key

1. Go to https://login.tailscale.com/admin/settings/keys
2. Create a reusable auth key
3. Store it as Kubernetes secret:

```bash
kubectl create secret generic tailscale-auth \
  --from-literal=authkey='tskey-auth-...' \
  -n fks-trading
```

### 3. Deploy Tailscale Connector

```bash
kubectl apply -f k8s/manifests/tailscale-connector.yaml
```

### 4. Get Tailscale IP

```bash
kubectl get svc tailscale-connector -n fks-trading
# Or check pod logs
kubectl logs -n fks-trading -l app=tailscale-connector
```

### 5. Update Cloudflare DNS

**Manual update:**
```bash
# Get current Tailscale IP
TAILSCALE_IP=$(kubectl get svc tailscale-connector -n fks-trading -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Update via GitHub Actions (trigger workflow)
# Or use script:
./scripts/update-cloudflare-dns.sh $TAILSCALE_IP
```

**Automatic update via GitHub Actions:**
- Push to main/master branch
- Workflow will check Tailscale IP
- Update Cloudflare DNS if different

## Configuration

### Environment Variables

- `TAILSCALE_AUTHKEY` - Tailscale authentication key (from secret)
- `TAILSCALE_HOSTNAME` - Hostname in Tailscale network (default: fkstrading-xyz)
- `CLOUDFLARE_ZONE_ID` - Cloudflare zone ID for fkstrading.xyz
- `CLOUDFLARE_API_TOKEN` - Cloudflare API token (GitHub secret)

### DNS Record

- **Type**: A
- **Name**: `fkstrading.xyz` (or `@`)
- **Content**: Tailscale IP address
- **TTL**: 300 (5 minutes)

## Files Structure

```
tailscale/
├── README.md                    # This file
├── .github/
│   └── workflows/
│       └── update-dns.yml      # GitHub Actions workflow
├── k8s/
│   └── manifests/
│       ├── tailscale-connector.yaml  # Tailscale Kubernetes deployment
│       └── tailscale-rbac.yaml      # RBAC for Tailscale
├── scripts/
│   ├── update-cloudflare-dns.sh     # Manual DNS update script
│   └── get-tailscale-ip.sh          # Get current Tailscale IP
└── docs/
    └── SETUP_GUIDE.md               # Detailed setup guide
```

## GitHub Actions

The workflow automatically:
1. Checks current Tailscale IP from Kubernetes
2. Compares with Cloudflare DNS record
3. Updates DNS if different
4. Can be triggered manually or on schedule

**Workflow triggers:**
- Push to main/master
- Manual workflow dispatch
- Scheduled (optional - daily check)

## Troubleshooting

### Tailscale not connecting
```bash
# Check pod status
kubectl get pods -n fks-trading -l app=tailscale-connector

# Check logs
kubectl logs -n fks-trading -l app=tailscale-connector

# Verify auth key
kubectl get secret tailscale-auth -n fks-trading -o jsonpath='{.data.authkey}' | base64 -d
```

### DNS not updating
```bash
# Check GitHub Actions workflow logs
# Verify Cloudflare API token is set
# Check DNS record manually
dig fkstrading.xyz
```

## Security

- ✅ Auth keys stored as Kubernetes secrets
- ✅ Cloudflare API token stored as GitHub secret
- ✅ RBAC limits Tailscale pod permissions
- ✅ Network policies (optional) to restrict access

## Support

For issues or questions:
- Check logs: `kubectl logs -n fks-trading -l app=tailscale-connector`
- Review GitHub Actions: https://github.com/nuniesmith/fks_tailscale/actions
- See docs: `docs/SETUP_GUIDE.md`

---

**Last Updated:** 2025-11-12

