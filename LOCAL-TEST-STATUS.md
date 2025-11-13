# Local Kubernetes Test Status

## Current Status

✅ **Minikube**: Running  
✅ **Namespace**: `fks-trading` exists  
✅ **RBAC**: Applied and fixed (can now create secrets)  
✅ **StatefulSet**: Deployed  
✅ **PVC**: Created and bound  
✅ **Pod**: Running (but not connected to Tailscale)  

## Issue Found

❌ **Secret**: The `tailscale-auth` secret contains a placeholder value `${TAILSCALE_AUTH_KEY}` instead of a real Tailscale auth key.

## Fix Required

You need to update the secret with a real Tailscale auth key:

### Option 1: Update Secret with Auth Key

```bash
# Get your Tailscale auth key from: https://login.tailscale.com/admin/settings/keys
export TAILSCALE_AUTHKEY='tskey-auth-...'

# Update the secret
kubectl create secret generic tailscale-auth \
  --from-literal=authkey="$TAILSCALE_AUTHKEY" \
  --from-literal=TS_AUTHKEY="$TAILSCALE_AUTHKEY" \
  -n fks-trading \
  --dry-run=client -o yaml | kubectl apply -f -

# Restart the pod
kubectl delete pod -n fks-trading tailscale-connector-0
```

### Option 2: Use the Quick Test Script

```bash
cd repo/tailscale
export TAILSCALE_AUTHKEY='tskey-auth-...'
./scripts/quick-test.sh
```

## Get Tailscale Auth Key

1. Go to https://login.tailscale.com/admin/settings/keys
2. Click "Generate auth key"
3. Make it **reusable** (if you want to use it for multiple nodes)
4. Set expiration (optional)
5. Copy the key (starts with `tskey-auth-...`)

## After Fixing

Once you update the secret with a real auth key:

1. **Restart the pod**:
   ```bash
   kubectl delete pod -n fks-trading tailscale-connector-0
   ```

2. **Wait for pod to be ready**:
   ```bash
   kubectl get pods -n fks-trading -l app=tailscale-connector
   ```

3. **Check Tailscale status**:
   ```bash
   kubectl exec -n fks-trading tailscale-connector-0 -- tailscale status
   ```

4. **Get Tailscale IP**:
   ```bash
   kubectl exec -n fks-trading tailscale-connector-0 -- tailscale ip -4
   ```

5. **Approve node in Tailscale admin** (if needed):
   - Go to https://login.tailscale.com/admin/machines
   - Find the node (hostname: `fkstrading-xyz` or `tailscale-connector-0`)
   - Approve it if it's pending

## Test Scaling

Once the node is connected, test scaling:

```bash
# Scale to 2 replicas
kubectl scale statefulset tailscale-connector -n fks-trading --replicas=2

# Check both pods
kubectl get pods -n fks-trading -l app=tailscale-connector

# Check Tailscale status in each pod
kubectl exec -n fks-trading tailscale-connector-0 -- tailscale status
kubectl exec -n fks-trading tailscale-connector-1 -- tailscale status
```

## Current Pod Status

```bash
# Check pod status
kubectl get pods -n fks-trading -l app=tailscale-connector

# Check logs
kubectl logs -n fks-trading tailscale-connector-0 -f

# Check events
kubectl describe pod -n fks-trading tailscale-connector-0
```

## Next Steps

1. ✅ Fix RBAC (done - can now create secrets)
2. ⏳ Update secret with real auth key
3. ⏳ Restart pod
4. ⏳ Verify Tailscale connection
5. ⏳ Test scaling
6. ⏳ Get Tailscale IP and update DNS (optional)

