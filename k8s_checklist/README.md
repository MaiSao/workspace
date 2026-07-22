---
Title: Kubernetes service health checklist
---

## Overview

`k8s_checklist/` is a standalone post-install health checker for a Kubernetes
cluster. It is intentionally independent from `../k8s_auto/`.

This checklist only answers whether enabled services are alive and available. It
does not compare static configuration files, image names, resource values, ports,
or other applied parameters.

Edit these files after installation:

```text
k8s_checklist/inventory.ini
k8s_checklist/group_vars/checklist.yml
```

`group_vars/checklist.yml` controls which built-in and extra services should be
checked.

## Run

Run from `k8s_checklist/`:

```shell
ansible-playbook -i inventory.ini playbook.yml
```

The command exits non-zero when a required host service is inactive, Kubernetes
API access fails, an inventory node is missing or not Ready, a required object is
missing, a Service has no ready endpoint, a workload rollout is unhealthy, or an
exporter/HA endpoint cannot be reached.

## What It Checks

- Host service health: `containerd`, `kubelet`, HAProxy, Keepalived, and `snmpd`
  when enabled.
- Host command probes: `ctr version`, `crictl info`, kubelet `/healthz`,
  kube-apiserver `/readyz`, kube-controller-manager `/healthz`,
  kube-scheduler `/healthz`, etcd `/health`, and HAProxy local API frontend.
- Kubernetes API health from the bootstrap master, including selected
  `APIService` availability and `kubectl get --raw` `/readyz` and `/livez`.
- Inventory nodes exist in Kubernetes and all inventory nodes are `Ready`.
- Core control-plane static pods are `Ready`: kube-apiserver,
  kube-controller-manager, kube-scheduler, and etcd.
- Expected service objects exist, for example namespaces, Services,
  ConfigMaps, CRDs, policies, StorageClasses, and CronJobs.
- Workloads are healthy through `kubectl rollout status` for Deployments,
  DaemonSets, and Elasticsearch StatefulSets.
- DaemonSets have all desired pods updated and available.
- StatefulSets have all replicas ready.
- Services that should receive traffic have ready Endpoints.
- HTTP Services are probed through the Kubernetes API service proxy for metrics
  and health endpoints such as CoreDNS, kube-state-metrics, cert-exporter,
  Fluent Bit, IP pool exporter, and Elasticsearch exporter.
- Node-level exporter health endpoints respond over HTTP, for example SNMP,
  SNMP switch, HAProxy, and Keepalived exporters.
- NodePort HTTP endpoints are probed for kube-state-metrics, Elasticsearch,
  Kibana, and Elasticsearch exporter when enabled.
- TCP endpoints are probed for the HA Kubernetes API VIP, CoreDNS TCP NodePort,
  and Elasticsearch transport NodePort when enabled.

## Scope

This health checklist deliberately does not validate:

- static files under `/etc` or `/var/lib`
- exact manifest parameters via JSONPath
- image names, resource requests/limits, hostPorts, or nodePorts
- CNI NAD parameter content
- installer-generated configuration snapshots

Those checks can live in a separate static/audit checklist if needed later.
