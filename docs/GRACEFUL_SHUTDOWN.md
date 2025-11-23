# Graceful Shutdown Implementation

## Overview

This project implements Kubernetes best practices for graceful pod termination during scale-down, rolling updates, and node draining. The goal is to **stop new work, finish what's running, then exit cleanly** without dropped requests or incomplete jobs.

## How It Works

### The Shutdown Sequence

1. **Deployment/KEDA decides to terminate a pod**
2. **preStop hook executes:**
   - Calls `/drain` endpoint (tells app to stop accepting new work)
   - Sleeps 10 seconds (allows Service/Ingress to remove pod from rotation)
3. **Pod removed from Service endpoints** (transitions out of Ready)
4. **kubelet sends SIGTERM** to container process (PID 1)
5. **Application handles SIGTERM:**
   - Stops accepting new requests
   - Finishes in-flight requests
   - Closes connections gracefully
6. **Grace period expires** (`terminationGracePeriodSeconds`)
7. **If still alive, SIGKILL** is sent

## Implementation Details

### Deployment Configuration

#### Backend (FastAPI/Python)
```yaml
terminationGracePeriodSeconds: 60  # Long enough for slowest request
minReadySeconds: 10                # Wait before trusting new pod
strategy:
  rollingUpdate:
    maxUnavailable: 0              # Keep all old pods Ready
    maxSurge: 1                    # Bring up new pods one at a time

lifecycle:
  preStop:
    exec:
      command:
        - /bin/sh
        - -c
        - |
          # Trigger drain mode (stop accepting new work)
          curl -fsS -XPOST http://127.0.0.1:8000/drain || echo "Drain endpoint not available"
          # Sleep to allow Service/Ingress to remove from rotation
          sleep 10
```

#### Frontend (Nginx)
```yaml
terminationGracePeriodSeconds: 30  # Enough for connections to finish
minReadySeconds: 10
strategy:
  rollingUpdate:
    maxUnavailable: 0
    maxSurge: 1

lifecycle:
  preStop:
    exec:
      command:
        - /bin/sh
        - -c
        - |
          # Sleep to allow Service/Ingress to remove from rotation
          sleep 10
          # Gracefully stop nginx (finishes existing connections)
          /usr/sbin/nginx -s quit
```

### Readiness Probe Configuration

Tight readiness for **fast drain state detection**:

```yaml
readinessProbe:
  httpGet:
    path: /ready  # or /healthz
    port: http
  periodSeconds: 3          # Check every 3 seconds (was 5)
  failureThreshold: 1       # Fail fast when draining (was 3)
```

When the app enters drain mode, `/ready` should return **503 Service Unavailable**, causing Kubernetes to immediately remove the pod from Service endpoints.

### KEDA Autoscaling with Graceful Scale-Down

```yaml
behavior:
  scaleDown:
    stabilizationWindowSeconds: 300  # Wait 5 minutes before scaling down
    policies:
      - type: Percent
        value: 50                    # Max 50% reduction
        periodSeconds: 60            # Every 60 seconds
      - type: Pods
        value: 1                     # Or 1 pod at a time
        periodSeconds: 60
    selectPolicy: Min                # Pick most conservative
  scaleUp:
    stabilizationWindowSeconds: 0    # Scale up immediately
    policies:
      - type: Percent
        value: 100                   # Up to 100% increase
        periodSeconds: 30
      - type: Pods
        value: 2                     # Or 2 pods at a time
        periodSeconds: 30
    selectPolicy: Max                # Pick most aggressive
```

**Key Points:**
- **Scale down slowly** (max 1 pod/minute or 50% every minute, whichever is less)
- **Wait 5 minutes** before starting scale-down (anti-flap)
- **Scale up fast** (up to 100% or 2 pods every 30 seconds)

### PodDisruptionBudget (PDB)

Prevents too many pods from being terminated at once:

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: backend-pdb
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: backend
```

**Effect:** During voluntary disruptions (drain, scale-down, updates), at least 1 pod must remain available.

## Application Code Requirements

### Backend (FastAPI/Python)

The backend needs to implement:

1. **`/drain` endpoint** - Sets drain mode flag
2. **`/ready` endpoint** - Returns 503 when draining
3. **SIGTERM handler** - Gracefully shuts down the server

Example:
```python
from fastapi import FastAPI, Response, status
import signal
import uvicorn

app = FastAPI()
draining = False

@app.post("/drain")
def drain():
    global draining
    draining = True
    return {"status": "draining"}

@app.get("/ready")
def ready(response: Response):
    if draining:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"status": "draining"}
    return {"status": "ready"}

def handle_sigterm(*_):
    global draining
    draining = True
    # Graceful shutdown: stop accepting, finish current, then exit
    import time
    time.sleep(55)  # Finish in-flight requests
    raise SystemExit(0)

signal.signal(signal.SIGTERM, handle_sigterm)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

### Frontend (Nginx)

Nginx handles graceful shutdown automatically:
- `nginx -s quit` finishes existing connections before exiting
- No code changes needed, just proper preStop hook

## Testing Graceful Shutdown

### 1. Test Rolling Update
```bash
# Start load test
kubectl run -it --rm load-gen --image=busybox --restart=Never -- sh -c \
  "while true; do wget -q -O- http://frontend-service/api/test; sleep 0.1; done"

# Trigger rollout
kubectl rollout restart deployment/backend -n sha-dev

# Watch pods
kubectl get pods -n sha-dev -w

# Check for no errors in load test
```

### 2. Test Scale Down
```bash
# Scale up
kubectl scale deployment/backend --replicas=3 -n sha-dev

# Generate load
# ... (same as above)

# Scale down
kubectl scale deployment/backend --replicas=1 -n sha-dev

# Verify no 5xx errors
kubectl logs -n sha-dev -l app=backend --tail=100 | grep -i error
```

### 3. Test Pod Deletion
```bash
# Start a long-running request (if applicable)
# ... 

# Delete pod
kubectl delete pod <backend-pod-name> -n sha-dev

# Verify:
# 1. preStop hook ran
kubectl describe pod <backend-pod-name> -n sha-dev

# 2. No connection errors in logs
kubectl logs -n sha-dev <backend-pod-name>

# 3. Pod took ~10-60 seconds to terminate (not immediate)
```

## Checklist

- ✅ `terminationGracePeriodSeconds` ≥ longest request time
- ✅ `preStop` hook calls `/drain` and sleeps
- ✅ Tight `readinessProbe` (periodSeconds=3, failureThreshold=1)
- ✅ App implements `/drain` and `/ready` endpoints
- ✅ App handles SIGTERM gracefully
- ✅ `minReadySeconds` configured (10s)
- ✅ `maxUnavailable: 0` in rolling update strategy
- ✅ PodDisruptionBudget configured
- ✅ KEDA `scaleDown.stabilizationWindowSeconds: 300`
- ✅ KEDA scale-down policies throttle pod removal

## Metrics to Monitor

- **Pod termination duration** - Should be ~10-60 seconds
- **5xx errors during rollout/scale-down** - Should be 0
- **In-flight request completion** - All should finish
- **Readiness transitions** - Pod should go NotReady quickly when draining

## Common Issues

### Issue: Pods killed immediately (< 10 seconds)
**Solution:** Check `terminationGracePeriodSeconds` is set high enough

### Issue: 502/503 errors during rollout
**Solution:** 
- Verify `maxUnavailable: 0`
- Check readiness probe is working
- Ensure preStop sleep gives LB time to remove

### Issue: Requests dropped during scale-down
**Solution:**
- Implement `/drain` endpoint
- Ensure readiness probe returns 503 when draining
- Increase `preStopSleepSeconds` if needed

### Issue: Too aggressive scale-down
**Solution:**
- Increase `stabilizationWindowSeconds` (default: 300s)
- Reduce `percentagePolicyValue` (default: 50)
- Reduce `podsPolicyValue` (default: 1)

## References

- [Kubernetes Pod Lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
- [Container Lifecycle Hooks](https://kubernetes.io/docs/concepts/containers/container-lifecycle-hooks/)
- [KEDA Scaling Behavior](https://keda.sh/docs/latest/concepts/scaling-deployments/#autoscaling-behavior)
- [PodDisruptionBudget](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/)
