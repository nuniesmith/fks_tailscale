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
- Kubernetes cluster (minikube, k3s, etc.) OR Docker Compose for local development

### 2. Setup Tailscale Auth Key

1. Go to https://login.tailscale.com/admin/settings/keys
2. Create a reusable auth key
3. Store it as Kubernetes secret (for K8s) or environment variable (for Docker Compose)

**Kubernetes:**
```bash
kubectl create secret generic tailscale-auth \
  --from-literal=authkey='tskey-auth-...' \
  -n fks-trading
```

**Docker Compose:**
```bash
export TAILSCALE_AUTHKEY='tskey-auth-...'
```

### 3. Deploy Tailscale Connector

**Kubernetes:**
```bash
# Apply RBAC first
kubectl apply -f k8s/manifests/tailscale-rbac.yaml

# Deploy Tailscale connector
kubectl apply -f k8s/manifests/tailscale-connector.yaml
```

**Docker Compose:**
```bash
# Build and run
docker-compose up -d

# Or use pre-built image
docker-compose -f docker-compose.yml up -d
```

### 4. Get Tailscale IP

**Kubernetes:**
```bash
# Get pod IP
kubectl get pods -n fks-trading -l app=tailscale-connector

# Check Tailscale status
kubectl exec -n fks-trading tailscale-connector-0 -- tailscale status

# Get Tailscale IP
kubectl exec -n fks-trading tailscale-connector-0 -- tailscale ip -4
```

**Docker Compose:**
```bash
# Check container status
docker-compose ps

# Get Tailscale IP
docker exec tailscale-node tailscale ip -4

# Check logs
docker-compose logs tailscale
```

### 5. Update Cloudflare DNS

**Manual update:**
```bash
# Get current Tailscale IP (K8s)
TAILSCALE_IP=$(kubectl exec -n fks-trading tailscale-connector-0 -- tailscale ip -4)

# Get current Tailscale IP (Docker Compose)
TAILSCALE_IP=$(docker exec tailscale-node tailscale ip -4)

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

- `TS_AUTHKEY` or `TS_AUTH_KEY` - Tailscale authentication key (from secret or env)
- `TS_HOSTNAME` - Hostname in Tailscale network (default: fkstrading-xyz)
- `TS_STATE_DIR` - Directory for Tailscale state (default: /var/lib/tailscale)
- `TS_USERSPACE` - Use userspace networking (default: false)
- `TS_ACCEPT_DNS` - Accept DNS configuration from Tailscale (default: true)
- `TS_EXTRA_ARGS` - Additional Tailscale arguments
- `CLOUDFLARE_ZONE_ID` - Cloudflare zone ID for fkstrading.xyz
- `CLOUDFLARE_API_TOKEN` - Cloudflare API token (GitHub secret)

### DNS Record

- **Type**: A
- **Name**: `fkstrading.xyz` (or `@`)
- **Content**: Tailscale IP address
- **TTL**: 300 (5 minutes)

### Scaling

Tailscale nodes can be scaled in Kubernetes. See [README-SCALING.md](README-SCALING.md) for detailed scaling instructions.

**Quick scaling:**
```bash
# Scale to 2 replicas
kubectl scale statefulset tailscale-connector -n fks-trading --replicas=2

# Scale to 3 replicas
kubectl scale statefulset tailscale-connector -n fks-trading --replicas=3
```

**Note**: Each node requires a unique hostname and persistent storage. See scaling guide for best practices.

## Files Structure

```
tailscale/
├── README.md                    # This file
├── README-SCALING.md           # Scaling guide
├── Dockerfile                   # Docker image for Tailscale
├── docker-compose.yml          # Docker Compose configuration
├── .dockerignore               # Docker ignore file
├── .github/
│   └── workflows/
│       ├── update-dns.yml      # DNS update workflow
│       └── docker-build-push.yml  # Docker build and push workflow
├── k8s/
│   └── manifests/
│       ├── tailscale-connector.yaml  # Tailscale Kubernetes StatefulSet
│       ├── tailscale-rbac.yaml      # RBAC for Tailscale
│       └── tailscale-hpa.yaml       # Horizontal Pod Autoscaler (optional)
├── scripts/
│   ├── update-cloudflare-dns.sh     # Manual DNS update script
│   └── get-tailscale-ip.sh          # Get current Tailscale IP
└── docs/
    └── SETUP_GUIDE.md               # Detailed setup guide
```

## GitHub Actions

### DNS Update Workflow

The DNS update workflow automatically:
1. Checks current Tailscale IP from Kubernetes
2. Compares with Cloudflare DNS record
3. Updates DNS if different
4. Can be triggered manually or on schedule

**Workflow triggers:**
- Push to main/master
- Manual workflow dispatch
- Scheduled (optional - daily check)

### Docker Build and Push Workflow

The Docker build workflow:
1. Validates Dockerfile and manifests
2. Builds Docker image
3. Pushes to DockerHub (nuniesmith/fks:tailscale-latest)

**Workflow triggers:**
- Push to main/master/develop
- Tags starting with "v*"
- Pull requests (validation only)

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

## Docker Compose

For local development or non-Kubernetes deployments:

```bash
# Set auth key
export TAILSCALE_AUTHKEY='tskey-auth-...'

# Build and run
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f tailscale

# Stop
docker-compose down
```

## Building Docker Image

```bash
# Build image
docker build -t nuniesmith/fks:tailscale-latest .

# Run locally
docker run -d \
  --name tailscale-node \
  --privileged \
  --network host \
  -e TS_AUTHKEY='tskey-auth-...' \
  -e TS_HOSTNAME='fkstrading-xyz' \
  -v tailscale-state:/var/lib/tailscale \
  nuniesmith/fks:tailscale-latest
```

## Support

For issues or questions:
- Check logs: `kubectl logs -n fks-trading -l app=tailscale-connector`
- Review GitHub Actions: https://github.com/nuniesmith/fks_tailscale/actions
- See docs: `docs/SETUP_GUIDE.md`
- Scaling guide: `README-SCALING.md`

---

**Last Updated:** 2025-11-13

