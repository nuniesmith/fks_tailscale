#!/bin/bash
# Quick test script for Tailscale in local K8s

set -e

NAMESPACE="fks-trading"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "🚀 Quick Test: Tailscale in Local Kubernetes"
echo "============================================="
echo ""

# Check if minikube is running
if ! minikube status > /dev/null 2>&1; then
    echo "❌ Minikube is not running. Please start it first:"
    echo "   minikube start"
    exit 1
fi

echo "✅ Minikube is running"

# Check for auth key
if [ -z "$TAILSCALE_AUTHKEY" ]; then
    echo "⚠️  TAILSCALE_AUTHKEY not set"
    echo "Please set it:"
    echo "   export TAILSCALE_AUTHKEY='tskey-auth-...'"
    echo ""
    read -p "Enter Tailscale auth key: " AUTH_KEY
    if [ -z "$AUTH_KEY" ]; then
        echo "❌ Auth key is required"
        exit 1
    fi
    export TAILSCALE_AUTHKEY="$AUTH_KEY"
fi

echo "✅ Auth key provided"

# Create namespace if it doesn't exist
kubectl create namespace "$NAMESPACE" 2>/dev/null || true
echo "✅ Namespace ready"

# Create or update secret
echo "📋 Creating/updating secret..."
kubectl create secret generic tailscale-auth \
    --from-literal=authkey="$TAILSCALE_AUTHKEY" \
    --from-literal=TS_AUTHKEY="$TAILSCALE_AUTHKEY" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Secret created/updated"

# Apply RBAC
echo "📋 Applying RBAC..."
kubectl apply -f "$REPO_DIR/k8s/manifests/tailscale-rbac.yaml"
echo "✅ RBAC applied"

# Apply Tailscale connector
echo "📋 Applying Tailscale connector..."
kubectl apply -f "$REPO_DIR/k8s/manifests/tailscale-connector.yaml"
echo "✅ Tailscale connector applied"

# Wait for pod
echo "📋 Waiting for pod to be ready (this may take 1-2 minutes)..."
if kubectl wait --for=condition=ready pod \
    -l app=tailscale-connector \
    -n "$NAMESPACE" \
    --timeout=300s 2>/dev/null; then
    echo "✅ Pod is ready!"
else
    echo "⚠️  Pod may still be starting. Checking status..."
    kubectl get pods -n "$NAMESPACE" -l app=tailscale-connector
fi

# Get pod name
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=tailscale-connector -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$POD_NAME" ]; then
    echo ""
    echo "📊 Pod Status:"
    kubectl get pods -n "$NAMESPACE" -l app=tailscale-connector
    
    echo ""
    echo "📋 Tailscale Status:"
    kubectl exec -n "$NAMESPACE" "$POD_NAME" -- tailscale status 2>/dev/null || echo "⚠️  Tailscale not connected yet. Check logs or Tailscale admin console."
    
    echo ""
    echo "📋 Tailscale IP:"
    TAILSCALE_IP=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- tailscale ip -4 2>/dev/null || echo "")
    if [ -n "$TAILSCALE_IP" ]; then
        echo "✅ Tailscale IP: $TAILSCALE_IP"
    else
        echo "⚠️  No IP yet. Node may still be connecting."
        echo "   Check Tailscale admin console: https://login.tailscale.com/admin/machines"
    fi
    
    echo ""
    echo "📋 Useful Commands:"
    echo "   kubectl logs -n $NAMESPACE $POD_NAME -f"
    echo "   kubectl exec -n $NAMESPACE $POD_NAME -- tailscale status"
    echo "   kubectl exec -n $NAMESPACE $POD_NAME -- tailscale ip -4"
else
    echo "⚠️  Pod not found. Check status:"
    kubectl get pods -n "$NAMESPACE" -l app=tailscale-connector
fi

echo ""
echo "✅ Test complete!"

