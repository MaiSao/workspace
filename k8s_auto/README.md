---
Title: Install Kubernetes guide
---

## Overview

This directory contains an Ansible-based Kubernetes installer. The main entry point is `site.yml`, a single play whose `roles` section defines the complete installation order. Service switches live at the top of `group_vars/services.yml`; role-level conditions decide which hosts perform each task.

Default behavior is still a full install. You only need to change service variables when you want to skip built-in phases or add future extra service roles.

## 1. Prepare Repositories

- Prepare Red Hat repositories. RHEL 8+ requires at least BaseOS and AppStream.
- Prepare the Kubernetes package repository used by the target nodes.
- Confirm all nodes can reach the configured repository endpoint from `group_vars/all.yml`.

## 2. Prepare Container Registry

- Use either Docker Registry or Harbor.
- For production, use a highly available registry.
- Confirm `registry_name`, `registry_ip`, `registry_port`, and `registry_protocol` in `group_vars/all.yml`.
- Confirm image lists in `group_vars/images.yml` match the Kubernetes and add-on versions you plan to install.

## 3. Prepare Ansible Inventory

The playbook expects `k8s-master` and `k8s-worker` groups. Use a stable inventory alias for each node, set its SSH management address with `ansible_host`, and explicitly set the address used by Kubernetes with `k8s_ip`. These addresses may be on different networks. Root access is required on all Kubernetes nodes.

```ini
[k8s-master]
master01 ansible_host=10.10.0.7 k8s_ip=1.255.0.7 ansible_ssh_user=root ansible_ssh_pass=myk8snow

[k8s-worker]
worker01 ansible_host=10.10.0.8 k8s_ip=1.255.0.8 ansible_ssh_user=root ansible_ssh_pass=myk8snow
```

The order of hosts in `k8s-master` defines Keepalived preference. The first
master starts at `keepalived_priority_base`; each following master decrements
by one for any supported master count. Use an odd control-plane count such as
1, 3, 5, or 7 for etcd quorum.

Place the final inventory at `k8s_auto/inventory.ini`.

## 4. Configure Cluster Variables

Review these files before running:

- `group_vars/all.yml`: commonly changed cluster, network, HA, registry, repository, path, and bootstrap settings followed by optional Kubernetes defaults.
- `group_vars/images.yml`: image names and image pull checklists.
- `group_vars/services.yml`: built-in/extra service switches first, then operator service configuration and advanced template defaults.
- `group_vars/resources.yml`: resource requests/limits for static pods, CNI, add-ons, CoreDNS, and kube-proxy.

## 5. Role Layout

The installer is split by responsibility:

```text
roles/cluster_preflight/       summary, runtime facts, and install-plan validation
roles/common/                 OS repo, packages, kernel modules, sysctl, hosts, kubelet bootstrap, etcd client tools
roles/containerd/             containerd package, registry config, crictl, service start
roles/haproxy/                HAProxy API load balancer
roles/keepalived/             Keepalived API VIP
roles/kubeadm/                prepare, init, kubeconfig, join
roles/calico/        Calico primary CNI
roles/multus/        Multus CNI
roles/whereabouts/   Whereabouts IPAM
roles/sriov/         SR-IOV device plugin and NADs
roles/macvlan/       macvlan NADs
roles/coredns/       CoreDNS override and rollout
roles/metrics_server/ metrics-server
roles/kube_state_metrics/ kube-state-metrics
roles/kubelet_csr_approver/ kubelet CSR approver
roles/kyverno/       Kyverno and policies
roles/etcd_jobs/     etcd backup/defrag jobs
roles/cert_exporter/ certificate expiration exporter
roles/ip_pools_exporter/ SR-IOV IP pools exporter
roles/snmp_exporter/ SNMP daemon config and SNMP exporter
roles/snmp_switch_exporter/ SNMP switch exporter
roles/haproxy_exporter/ HAProxy exporter DaemonSet on master nodes
roles/keepalived_exporter/ Keepalived exporter DaemonSet on master nodes
roles/fluentbit/     optional Fluent Bit extra service for cluster, host, and application logs
roles/local_path_provisioner/ optional Rancher local-path storage provisioner
roles/elasticsearch/ optional Elasticsearch, Kibana, and Elasticsearch exporter stack
roles/k8s_tuning/             workload resources and static pod tuning
```

`site.yml` lists every role explicitly in execution order. Each role entry has an enable condition sourced from `k8s_services`, the CNI option switches, or `k8s_extra_services`. Role-level checks further restrict all-node, master-only, bootstrap-master, worker-join, and optional work.

## 6. Service Selection

Built-in and extra services are enabled at the top of `group_vars/services.yml`:

```yaml
k8s_services:
  common: true
  containerd: true
  kubeadm: true
  calico: true
  coredns: true
  ip_pools_exporter: false

k8s_extra_services:
  fluentbit: true
  local_path_provisioner: true
  elasticsearch: true
```

Set a value to `true` or `false`; execution order and host placement remain explicit in `site.yml`. Macvlan and SR-IOV remain network feature switches in `group_vars/all.yml`.

Example: run only CoreDNS after the cluster exists:

```shell
ansible-playbook -i inventory.ini site.yml \
  -e '{"k8s_services":{"coredns":true}}'
```

Example: update resource values for kubeadm-created workloads after editing `group_vars/resources.yml`:

```shell
ansible-playbook -i inventory.ini site.yml \
  -e '{"k8s_services":{"k8s_tuning":true}}'
```

Example: run selected exporters after the cluster exists:

```shell
ansible-playbook -i inventory.ini site.yml \
  -e '{"k8s_services":{"cert_exporter":true,"snmp_exporter":true,"haproxy_exporter":true}}'
```

`ip_pools_exporter` also requires `multus_sriov: true`.

## 7. Deploy Full Cluster

Run from `k8s_auto/`:

```shell
ansible-playbook -i inventory.ini site.yml
```

Warning: bootstrap tasks reset Kubernetes, CNI, kubeconfig, and etcd state on target nodes. Run only on nodes intended for this cluster.

## 8. Enable Or Disable Extra Services

Extra services are selected at the top of `group_vars/services.yml` and run near the end of `site.yml` on the bootstrap master:

```yaml
k8s_extra_services:
  fluentbit: true
  local_path_provisioner: true
  elasticsearch: true
```

Run the single playbook from `k8s_auto/`:

```shell
ansible-playbook -i inventory.ini site.yml
```

For Fluent Bit, adjust the small deployment variable set in `group_vars/services.yml`: namespace, cluster name, Elasticsearch endpoint/credential, host paths, and `fluentbit_profiles`. Native Fluent Bit config templates live under `roles/fluentbit/templates/conf/`.

For Local Path Provisioner, adjust `local_path_default_path`, `local_path_storage_class_name`, and related `local_path_*` values in `group_vars/services.yml`.

For Elasticsearch, label target nodes before applying:

```shell
kubectl label node <master-node> es-role=master
kubectl label node <data-node> es-role=data
kubectl label node <client-node> es-role=client
```

Elasticsearch depends on Local Path Provisioner for its data and log PVC StorageClasses. Keep `local_path_provisioner` enabled and before `elasticsearch`; the role waits for the provisioner rollout before applying Elasticsearch manifests. Elasticsearch renders separate config maps for master, data, and client node sets while sharing `elasticsearch-log4j2` and `jvm-config`. After the Elasticsearch StatefulSets are ready, a short-lived `elasticsearch-post-install` Job sets the `kibana_system` password from `elasticsearch_kibana_auth`; Kibana and the exporter are applied only after that job succeeds.

## 9. Add Future Extra Services

Create a new role under `roles/`, for example:

```text
roles/k8s_ingress_nginx/
  tasks/main.yml
  templates/
  defaults/main.yml
```

Add it to `k8s_extra_services` in `group_vars/services.yml`, then list its role explicitly in `site.yml`:

```yaml
k8s_extra_services:
  ingress_nginx: true
```

Then run:

```shell
ansible-playbook -i inventory.ini site.yml
```

To disable one extra service, set it to `false`. To disable all extra services:

```yaml
k8s_extra_services:
  fluentbit: false
  local_path_provisioner: false
  elasticsearch: false
```
