# Testing Tailscale in Local Kubernetes (Minikube)

This guide helps you test the Tailscale connector in a local Kubernetes cluster using minikube.

## Prerequisites

- Minikube installed and running
- kubectl configured
- Tailscale account and auth key
- Docker (for building image locally if needed)

## Quick Start

### 1. Start Minikube (if not running)

```bash
minikube start
```

### 2. Get Tailscale Auth Key

1. Go to https://login.tailscale.com/admin/settings/keys
2. Create a reusable auth key
3. Copy the key (starts with `tskey-auth-...`)

### 3. Run Test Script

```bash
cd repo/tailscale
export TAILSCALE_AUTHKEY='tskey-auth-...'
./scripts/test-local-k8s.sh
```

Or run manually:

### 3. Manual Setup

#### Create Namespace

```bash
kubectl create namespace fks-trading
```

#### Create Secret

```bash
kubectl create secret generic tailscale-auth \
  --from-literal=authkey='tskey-auth-...' \
  --from-literal=TS_AUTHKEY='tskey-auth-...' \
  -n fks-trading
```

#### Apply RBAC

```bash
kubectl apply -f k8s/manifests/tailscale-rbac.yaml
```

#### Build and Load Image (Optional)

If you want to test with a custom image:

```bash
# Build image
docker build -t nuniesmith/fks:tailscale-latest .

# Load into minikube
minikube image load nuniesmith/fks:tailscale-latest
```

Or use the official Tailscale image by modifying the manifest temporarily:

```yaml
# In tailscale-connector.yaml, change:
image: tailscale/tailscale:latest
# Instead of:
image: nuniesmith/fks:tailscale-latest
```

#### Apply Tailscale Connector

```bash
kubectl apply -f k8s/manifests/tailscale-connector.yaml
```

## Verify Deployment

### Check Pod Status

```bash
kubectl get pods -n fks-trading -l app=tailscale-connector
```

Wait for pod to be in `Running` state.

### Check Logs

```bash
POD_NAME=$(kubectl get pods -n fks-trading -l app=tailscale-connector -o jsonpath='{.items[0].metadata.name}')
kubectl logs -n fks-trading $POD_NAME -f
```

### Check Tailscale Status

```bash
kubectl exec -n fks-trading $POD_NAME -- tailscale status
```

### Get Tailscale IP

```bash
kubectl exec -n fks-trading $POD_NAME -- tailscale ip -4
```

## Troubleshooting

### Pod Not Starting

If the pod is stuck in `Pending` or `CrashLoopBackOff`:

1. **Check pod events:**
   ```bash
   kubectl describe pod -n fks-trading -l app=tailscale-connector
   ```

2. **Check logs:**
   ```bash
   kubectl logs -n fks-trading -l app=tailscale-connector --tail=100
   ```

3. **Common issues:**
   - **Image pull errors**: Build and load image locally or use official image
   - **Privileged mode**: Minikube should support privileged containers
   - **Volume issues**: Check if `/dev/net/tun` exists in minikube

### Node Not Connecting

1. **Check Tailscale admin console:**
   - Go to https://login.tailscale.com/admin/machines
   - Look for the node (hostname: `fkstrading-xyz` or pod name)
   - Approve the node if needed

2. **Check auth key:**
   ```bash
   kubectl get secret tailscale-auth -n fks-trading -o jsonpath='{.data.authkey}' | base64 -d
   ```

3. **Check Tailscale logs:**
   ```bash
   kubectl logs -n fks-trading -l app=tailscale-connector | grep -i tailscale
   ```

### Persistent Volume Issues

If PVC is stuck in `Pending`:

1. **Check storage class:**
   ```bash
   kubectl get storageclass
   ```

2. **Check PVC:**
   ```bash
   kubectl get pvc -n fks-trading
   kubectl describe pvc -n fks-trading tailscale-state-tailscale-connector-0
   ```

3. **Minikube default storage class:**
   Minikube should have a default storage class. If not:
   ```bash
   minikube addons enable default-storageclass
   ```

## Testing Scaling

### Scale to 2 Replicas

```bash
kubectl scale statefulset tailscale-connector -n fks-trading --replicas=2
```

### Check Both Pods

```bash
kubectl get pods -n fks-trading -l app=tailscale-connector
```

### Check Tailscale Status in Each Pod

```bash
# Pod 0
kubectl exec -n fks-trading tailscale-connector-0 -- tailscale status

# Pod 1
kubectl exec -n fks-trading tailscale-connector-1 -- tailscale status
```

### Scale Back to 1

```bash
kubectl scale statefulset tailscale-connector -n fks-trading --replicas=1
```

## Cleanup

### Delete Deployment

```bash
kubectl delete -f k8s/manifests/tailscale-connector.yaml
kubectl delete -f k8s/manifests/tailscale-rbac.yaml
```

### Delete Namespace (removes everything)

```bash
kubectl delete namespace fks-trading
```

### Stop Minikube (optional)

```bash
minikube stop
```

## Next Steps

After successful local testing:

1. **Build and push Docker image:**
   ```bash
   docker build -t nuniesmith/fks:tailscale-latest .
   docker push nuniesmith/fks:tailscale-latest
   ```

2. **Deploy to production cluster:**
   - Update image references if needed
   - Apply manifests to production cluster
   - Verify connectivity

3. **Set up GitHub Actions:**
   - Configure DockerHub secrets
   - Push to trigger build workflow
   - Verify automated builds

## Useful Commands

```bash
# Get pod name
POD_NAME=$(kubectl get pods -n fks-trading -l app=tailscale-connector -o jsonpath='{.items[0].metadata.name}')

# Exec into pod
kubectl exec -n fks-trading $POD_NAME -it -- /bin/sh

# Check Tailscale IP
kubectl exec -n fks-trading $POD_NAME -- tailscale ip -4

# Check Tailscale status
kubectl exec -n fks-trading $POD_NAME -- tailscale status --json | jq

# Port forward (if needed)
kubectl port-forward -n fks-trading $POD_NAME 41641:41641

# Watch pods
kubectl get pods -n fks-trading -l app=tailscale-connector -w

# Watch logs
kubectl logs -n fks-trading -l app=tailscale-connector -f
```

