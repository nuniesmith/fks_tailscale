#!/bin/bash
# Update Tailscale auth secret in Kubernetes

set -e

NAMESPACE="${NAMESPACE:-fks-trading}"

echo "🔐 Update Tailscale Auth Secret"
echo "================================"
echo ""

# Check if auth key is provided
if [ -z "$TAILSCALE_AUTHKEY" ]; then
    echo "⚠️  TAILSCALE_AUTHKEY not set"
    echo ""
    echo "Please provide your Tailscale auth key:"
    echo "  1. Go to: https://login.tailscale.com/admin/settings/keys"
    echo "  2. Generate a reusable auth key"
    echo "  3. Copy the key (starts with 'tskey-auth-...')"
    echo ""
    read -p "Enter Tailscale auth key: " AUTH_KEY
    if [ -z "$AUTH_KEY" ]; then
        echo "❌ Auth key is required"
        exit 1
    fi
    export TAILSCALE_AUTHKEY="$AUTH_KEY"
fi

# Validate auth key format
if [[ ! "$TAILSCALE_AUTHKEY" =~ ^tskey-auth- ]]; then
    echo "⚠️  Warning: Auth key doesn't start with 'tskey-auth-'"
    echo "   Are you sure this is the correct key?"
    read -p "Continue anyway? (y/N): " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo "❌ Aborted"
        exit 1
    fi
fi

echo "✅ Auth key provided"
echo ""

# Update secret
echo "📋 Updating secret in namespace: $NAMESPACE..."
kubectl create secret generic tailscale-auth \
    --from-literal=authkey="$TAILSCALE_AUTHKEY" \
    --from-literal=TS_AUTHKEY="$TAILSCALE_AUTHKEY" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Secret updated"
echo ""

# Check if pod exists
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=tailscale-connector -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$POD_NAME" ]; then
    echo "📋 Restarting pod: $POD_NAME..."
    kubectl delete pod -n "$NAMESPACE" "$POD_NAME"
    echo "✅ Pod restarted"
    echo ""
    echo "⏳ Waiting for pod to be ready..."
    sleep 5
    kubectl wait --for=condition=ready pod \
        -l app=tailscale-connector \
        -n "$NAMESPACE" \
        --timeout=300s 2>/dev/null && echo "✅ Pod is ready!" || echo "⚠️  Pod may still be starting"
else
    echo "⚠️  No pod found. Deploy the StatefulSet first:"
    echo "   kubectl apply -f k8s/manifests/tailscale-connector.yaml"
fi

echo ""
echo "📋 Next Steps:"
echo "  1. Check pod status: kubectl get pods -n $NAMESPACE -l app=tailscale-connector"
echo "  2. Check logs: kubectl logs -n $NAMESPACE $POD_NAME -f"
echo "  3. Check Tailscale status: kubectl exec -n $NAMESPACE $POD_NAME -- tailscale status"
echo "  4. Get Tailscale IP: kubectl exec -n $NAMESPACE $POD_NAME -- tailscale ip -4"
echo "  5. Approve node in Tailscale admin: https://login.tailscale.com/admin/machines"
echo ""
echo "✅ Done!"

