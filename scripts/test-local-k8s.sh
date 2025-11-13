#!/bin/bash
# Test Tailscale deployment in local Kubernetes (minikube)

set -e

NAMESPACE="fks-trading"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔧 Testing Tailscale in Local Kubernetes"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if minikube is running
echo "📋 Checking minikube status..."
if ! minikube status > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Minikube is not running. Starting minikube...${NC}"
    minikube start
else
    echo -e "${GREEN}✅ Minikube is running${NC}"
fi

# Check if kubectl can connect
echo "📋 Checking kubectl connection..."
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    exit 1
else
    echo -e "${GREEN}✅ kubectl connected${NC}"
fi

# Create namespace
echo "📋 Creating namespace: $NAMESPACE..."
kubectl create namespace "$NAMESPACE" 2>/dev/null || echo -e "${YELLOW}⚠️  Namespace already exists${NC}"

# Check for Tailscale auth key
echo "📋 Checking for Tailscale auth key..."
if [ -z "$TAILSCALE_AUTHKEY" ]; then
    echo -e "${YELLOW}⚠️  TAILSCALE_AUTHKEY not set${NC}"
    echo "Please set it:"
    echo "  export TAILSCALE_AUTHKEY='tskey-auth-...'"
    echo ""
    read -p "Enter Tailscale auth key (or press Enter to skip secret creation): " AUTH_KEY
    if [ -n "$AUTH_KEY" ]; then
        TAILSCALE_AUTHKEY="$AUTH_KEY"
    else
        echo -e "${YELLOW}⚠️  Skipping secret creation. You'll need to create it manually:${NC}"
        echo "  kubectl create secret generic tailscale-auth \\"
        echo "    --from-literal=authkey='tskey-auth-...' \\"
        echo "    -n $NAMESPACE"
        echo ""
    fi
fi

# Create secret if auth key is provided
if [ -n "$TAILSCALE_AUTHKEY" ]; then
    echo "📋 Creating Tailscale auth secret..."
    kubectl create secret generic tailscale-auth \
        --from-literal=authkey="$TAILSCALE_AUTHKEY" \
        --from-literal=TS_AUTHKEY="$TAILSCALE_AUTHKEY" \
        -n "$NAMESPACE" \
        --dry-run=client -o yaml | kubectl apply -f -
    echo -e "${GREEN}✅ Secret created${NC}"
fi

# Apply RBAC
echo "📋 Applying RBAC..."
kubectl apply -f "$REPO_DIR/k8s/manifests/tailscale-rbac.yaml"
echo -e "${GREEN}✅ RBAC applied${NC}"

# Apply Tailscale connector
echo "📋 Applying Tailscale connector..."
kubectl apply -f "$REPO_DIR/k8s/manifests/tailscale-connector.yaml"
echo -e "${GREEN}✅ Tailscale connector applied${NC}"

# Wait for pod to be ready
echo "📋 Waiting for Tailscale pod to be ready..."
echo "This may take a minute or two..."
kubectl wait --for=condition=ready pod \
    -l app=tailscale-connector \
    -n "$NAMESPACE" \
    --timeout=300s || {
    echo -e "${RED}❌ Pod did not become ready in time${NC}"
    echo "Checking pod status..."
    kubectl get pods -n "$NAMESPACE" -l app=tailscale-connector
    echo ""
    echo "Checking logs..."
    kubectl logs -n "$NAMESPACE" -l app=tailscale-connector --tail=50
    exit 1
}

echo -e "${GREEN}✅ Pod is ready${NC}"

# Get pod name
POD_NAME=$(kubectl get pods -n "$NAMESPACE" -l app=tailscale-connector -o jsonpath='{.items[0].metadata.name}')

# Check Tailscale status
echo "📋 Checking Tailscale status..."
echo ""
kubectl exec -n "$NAMESPACE" "$POD_NAME" -- tailscale status || {
    echo -e "${YELLOW}⚠️  Tailscale status check failed. This is normal if the node hasn't connected yet.${NC}"
}

# Get Tailscale IP
echo "📋 Getting Tailscale IP..."
TAILSCALE_IP=$(kubectl exec -n "$NAMESPACE" "$POD_NAME" -- tailscale ip -4 2>/dev/null || echo "")
if [ -n "$TAILSCALE_IP" ]; then
    echo -e "${GREEN}✅ Tailscale IP: $TAILSCALE_IP${NC}"
else
    echo -e "${YELLOW}⚠️  Could not get Tailscale IP yet. The node may still be connecting.${NC}"
    echo "Check the Tailscale admin console: https://login.tailscale.com/admin/machines"
    echo "Make sure the node is approved."
fi

# Show pod information
echo ""
echo "📋 Pod Information:"
echo "==================="
kubectl get pods -n "$NAMESPACE" -l app=tailscale-connector
echo ""

# Show service information
echo "📋 Service Information:"
echo "======================"
kubectl get svc -n "$NAMESPACE" -l app=tailscale-connector
echo ""

# Show useful commands
echo "📋 Useful Commands:"
echo "==================="
echo "  # Check pod status"
echo "  kubectl get pods -n $NAMESPACE -l app=tailscale-connector"
echo ""
echo "  # View logs"
echo "  kubectl logs -n $NAMESPACE $POD_NAME -f"
echo ""
echo "  # Check Tailscale status"
echo "  kubectl exec -n $NAMESPACE $POD_NAME -- tailscale status"
echo ""
echo "  # Get Tailscale IP"
echo "  kubectl exec -n $NAMESPACE $POD_NAME -- tailscale ip -4"
echo ""
echo "  # Scale to 2 replicas"
echo "  kubectl scale statefulset tailscale-connector -n $NAMESPACE --replicas=2"
echo ""
echo "  # Delete deployment"
echo "  kubectl delete -f $REPO_DIR/k8s/manifests/tailscale-connector.yaml"
echo "  kubectl delete -f $REPO_DIR/k8s/manifests/tailscale-rbac.yaml"
echo "  kubectl delete namespace $NAMESPACE"
echo ""

echo -e "${GREEN}✅ Testing complete!${NC}"
echo ""
echo "🔍 Next Steps:"
echo "  1. Check Tailscale admin console to approve the node"
echo "  2. Wait for the node to connect (may take 1-2 minutes)"
echo "  3. Get the Tailscale IP and update Cloudflare DNS"
echo "  4. Test connectivity from other Tailscale devices"

