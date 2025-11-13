#!/bin/bash
# Get current Tailscale IP from Kubernetes

set -e

NAMESPACE="${NAMESPACE:-fks-trading}"
HOSTNAME="${TAILSCALE_HOSTNAME:-fkstrading-xyz}"

echo "Getting Tailscale IP for $HOSTNAME..."

# Method 1: Try Kubernetes service
if kubectl get svc tailscale-connector -n "$NAMESPACE" &>/dev/null; then
    IP=$(kubectl get svc tailscale-connector -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [ -n "$IP" ]; then
        echo "✅ Tailscale IP from Kubernetes: $IP"
        echo "$IP"
        exit 0
    fi
fi

# Method 2: Try DNS resolution
if command -v dig &> /dev/null; then
    IP=$(dig +short "${HOSTNAME}.tailscale.ts.net" | grep -E '^100\.' | head -1)
    if [ -n "$IP" ]; then
        echo "✅ Tailscale IP from DNS: $IP"
        echo "$IP"
        exit 0
    fi
fi

# Method 3: Try Tailscale CLI (if available)
if command -v tailscale &> /dev/null; then
    IP=$(tailscale status --json 2>/dev/null | jq -r ".Self.addresses[] | select(startswith(\"100.\"))" | head -1)
    if [ -n "$IP" ]; then
        echo "✅ Tailscale IP from CLI: $IP"
        echo "$IP"
        exit 0
    fi
fi

echo "❌ Could not determine Tailscale IP"
exit 1

