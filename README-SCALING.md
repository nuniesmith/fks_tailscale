# Tailscale Scaling Guide

## Overview

This guide explains how to scale Tailscale nodes in Kubernetes. Tailscale nodes are typically unique and each node requires:

1. A unique hostname
2. An authentication key (can be shared or per-node)
3. Persistent state storage

## Scaling Considerations

### Single Node (Default)

The default configuration runs a single Tailscale node with hostname `fkstrading-xyz`. This is the recommended setup for most use cases.

### Multiple Nodes

If you need multiple Tailscale nodes:

1. **Each node must have a unique hostname** - Tailscale will automatically append a suffix if hostnames conflict
2. **Shared auth key** - You can use the same auth key for multiple nodes, or create separate keys per node
3. **Persistent storage** - Each node requires its own persistent volume for state

## Scaling Methods

### Method 1: Scale StatefulSet (Simple)

Scale the StatefulSet to increase replicas:

```bash
# Scale to 2 replicas
kubectl scale statefulset tailscale-connector -n fks-trading --replicas=2

# Scale to 3 replicas
kubectl scale statefulset tailscale-connector -n fks-trading --replicas=3
```

**Note**: Each pod will have a unique name (tailscale-connector-0, tailscale-connector-1, etc.), but they will share the same `TS_HOSTNAME`. Tailscale will automatically handle hostname conflicts by appending suffixes.

### Method 2: Manual Scaling with Unique Hostnames (Recommended)

For better control, manually scale with unique hostnames:

1. **Update StatefulSet** to use pod name for hostname:

```yaml
env:
- name: TS_HOSTNAME
  valueFrom:
    fieldRef:
      fieldPath: metadata.name
```

2. **Scale the StatefulSet**:

```bash
kubectl scale statefulset tailscale-connector -n fks-trading --replicas=3
```

3. **Each pod will have hostname**: `tailscale-connector-0`, `tailscale-connector-1`, `tailscale-connector-2`

### Method 3: Separate StatefulSets (Advanced)

Create separate StatefulSets for different purposes:

```yaml
# Primary node
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: tailscale-primary
  namespace: fks-trading
spec:
  serviceName: tailscale-primary
  replicas: 1
  template:
    spec:
      containers:
      - name: tailscale
        env:
        - name: TS_HOSTNAME
          value: "fkstrading-xyz-primary"

---
# Secondary node
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: tailscale-secondary
  namespace: fks-trading
spec:
  serviceName: tailscale-secondary
  replicas: 1
  template:
    spec:
      containers:
      - name: tailscale
        env:
        - name: TS_HOSTNAME
          value: "fkstrading-xyz-secondary"
```

## Horizontal Pod Autoscaler (HPA)

The HPA is provided for reference but **not recommended** for Tailscale nodes because:

1. Tailscale nodes are stateful and require unique identities
2. Auto-scaling can cause issues with persistent state
3. Each node requires manual approval in Tailscale admin console

If you want to use HPA, apply it with caution:

```bash
# Apply HPA (not recommended for production)
kubectl apply -f k8s/manifests/tailscale-hpa.yaml
```

## Scaling Best Practices

1. **Start with 1 node** - Add nodes only when needed
2. **Use unique hostnames** - Prevents conflicts and makes management easier
3. **Monitor resource usage** - Tailscale nodes are lightweight but monitor CPU/memory
4. **Approve nodes in Tailscale admin** - New nodes require approval in the Tailscale admin console
5. **Use persistent storage** - Each node needs its own PVC for state
6. **Test scaling** - Test scaling in a non-production environment first

## Checking Node Status

```bash
# List all Tailscale pods
kubectl get pods -n fks-trading -l app=tailscale-connector

# Check Tailscale status in a pod
kubectl exec -n fks-trading tailscale-connector-0 -- tailscale status

# Get Tailscale IP
kubectl exec -n fks-trading tailscale-connector-0 -- tailscale ip -4

# Check logs
kubectl logs -n fks-trading tailscale-connector-0
```

## Troubleshooting Scaling Issues

### Node Not Appearing in Tailscale

1. Check if node is approved in Tailscale admin console
2. Verify auth key is valid
3. Check pod logs for errors
4. Verify hostname is unique

### Hostname Conflicts

If multiple nodes have the same hostname:
1. Tailscale will automatically append suffixes (e.g., `fkstrading-xyz-1`, `fkstrading-xyz-2`)
2. You can rename nodes in Tailscale admin console
3. Update TS_HOSTNAME to use unique values

### State Issues

If nodes lose state:
1. Check persistent volume claims
2. Verify volumes are mounted correctly
3. Check pod restarts and events

## References

- [Tailscale Kubernetes Documentation](https://tailscale.com/kb/1245/kubernetes)
- [StatefulSet Scaling](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/#scaling)
- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

