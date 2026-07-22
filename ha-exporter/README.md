# HA Exporters

Standalone manifests for HAProxy exporter and Keepalived exporter.

These manifests run only on Kubernetes control-plane/master nodes by using node
affinity and tolerations. They assume HAProxy and Keepalived are already running
on those hosts.

## Files

- `haproxy-exporter.yaml`: DaemonSet for HAProxy metrics on port `9101`.
- `keepalived-exporter.yaml`: DaemonSet and ClusterIP Service for Keepalived metrics on port `9165`.

## Prerequisites

- Images must exist in the private registry:
  - `docker-registry:4000/vht/haproxy-exporter:v0.15.0`
  - `docker-registry:4000/vht/keepalived-exporter:v1.7.1-el8`
- HAProxy must expose stats on each master at `127.0.0.1:8404`.
- Keepalived must write its PID file at `/run/keepalived.pid`.
- Control-plane nodes must have either of these labels:
  - `node-role.kubernetes.io/control-plane`
  - `node-role.kubernetes.io/master`

## HAProxy Stats Configuration

HAProxy exporter scrapes HAProxy through this URL:

```text
http://127.0.0.1:8404/;csv
```

Each master must expose a local HAProxy stats listener. Add a fragment like this
to HAProxy, for example `/etc/haproxy/conf.d/k8s-haproxy-stats.cfg`:

```haproxy
listen k8s_haproxy_stats
    bind 127.0.0.1:8404
    mode http
    stats enable
    stats uri /
    stats refresh 10s
```

If HAProxy is managed with a main config plus fragments, make sure the HAProxy
systemd unit loads both files. Example:

```ini
ExecStart=
ExecStart=/usr/sbin/haproxy -Ws -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/conf.d
```

Then validate and restart HAProxy:

```bash
haproxy -c -f /etc/haproxy/haproxy.cfg -f /etc/haproxy/conf.d
systemctl restart haproxy
curl http://127.0.0.1:8404/;csv
```

## Apply

```bash
kubectl apply -f haproxy-exporter.yaml
kubectl apply -f keepalived-exporter.yaml
```

Or apply the whole directory:

```bash
kubectl apply -f .
```

## Verify

```bash
kubectl -n kube-system get ds haproxy-exporter keepalived-exporter -o wide
kubectl -n kube-system rollout status ds/haproxy-exporter
kubectl -n kube-system rollout status ds/keepalived-exporter
kubectl -n kube-system get pods -l app=haproxy-exporter -o wide
kubectl -n kube-system get pods -l app.kubernetes.io/name=keepalived-exporter -o wide
```

Check metrics on each master node:

```bash
curl http://<master-ip>:9101/metrics
curl http://<master-ip>:9165/metrics
```

## Remove

```bash
kubectl delete -f keepalived-exporter.yaml
kubectl delete -f haproxy-exporter.yaml
```

## Notes

- HAProxy exporter uses `hostNetwork: true` and `hostPort: 9101`.
- Keepalived exporter uses `hostPID: true` and mounts `/run` and `/tmp` from the host.
- If your registry, HAProxy stats port, or Keepalived PID path differs, edit the YAML files before applying.
