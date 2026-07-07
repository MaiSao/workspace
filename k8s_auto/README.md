---
Title: Install Kubernetes guide
---

## Overview

This directory contains an Ansible-based Kubernetes installer. The main entry point is `site.yml`, a single play that targets all nodes and lists each split role once. Each role decides what to do from host group membership and the install plan at the top of `group_vars/all.yml`.

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

The playbook expects a `master` group. Each node must define `k8s_ip`. Root access is required on all Kubernetes nodes.

```ini
[master]
1.255.0.7 priority=5 k8s_ip=1.255.0.7 ansible_ssh_user=root ansible_ssh_pass=myk8snow

[worker]
1.255.0.8 k8s_ip=1.255.0.8 ansible_ssh_user=root ansible_ssh_pass=myk8snow
```

Place the final inventory at `k8s_auto/inventory.ini`.

## 4. Configure Cluster Variables

Review these files before running:

- `group_vars/all.yml`: install plan, extra service selection, Kubernetes version, networking, registry, repo, VIP, audit, etcd, containerd, and bootstrap settings.
- `group_vars/images.yml`: image names and image pull checklists.
- `group_vars/services.yml`: per-service manifest lists, add-on switches, exporter settings, and extra-service configuration.
- `group_vars/resources.yml`: resource requests/limits for static pods, CNI, add-ons, CoreDNS, and kube-proxy.

## 5. Role Layout

The installer is split by responsibility:

```text
roles/common/                 OS repo, packages, kernel modules, sysctl, hosts, kubelet bootstrap, etcd client tools
roles/containerd/             containerd package, registry config, crictl, service start
roles/haproxy/                HAProxy API load balancer
roles/keepalived/             Keepalived API VIP
roles/kubeadm/                prepare, init, kubeconfig, join
roles/services/calico/        Calico primary CNI
roles/services/multus/        Multus CNI
roles/services/whereabouts/   Whereabouts IPAM
roles/services/sriov/         SR-IOV device plugin and NADs
roles/services/macvlan/       macvlan NADs
roles/services/coredns/       CoreDNS override and rollout
roles/services/metrics_server/ metrics-server
roles/services/kube_state_metrics/ kube-state-metrics
roles/services/kubelet_csr_approver/ kubelet CSR approver
roles/services/kyverno/       Kyverno and policies
roles/services/etcd_jobs/     etcd backup/defrag jobs
roles/services/cert_exporter/ certificate expiration exporter
roles/services/ip_pools_exporter/ SR-IOV IP pools exporter
roles/services/snmp_exporter/ SNMP daemon config and SNMP exporter
roles/services/snmp_switch_exporter/ SNMP switch exporter
roles/services/haproxy_exporter/ HAProxy host-service exporter
roles/services/keepalived_exporter/ Keepalived host-service exporter
roles/services/fluentbit/     optional Fluent Bit extra service for cluster, host, and application logs
roles/services/local_path_provisioner/ optional Rancher local-path storage provisioner
roles/services/elasticsearch/ optional Elasticsearch, Kibana, and Elasticsearch exporter stack
roles/k8s_tuning/             workload resources and static pod tuning
```

`site.yml` includes enabled roles from `k8s_service_groups` in `group_vars/all.yml`. Role-level `when` checks restrict master-only work, first-master work, worker joins, and optional services.

## 6. Service Catalog

Built-in services are defined as an enable catalog at the top of `group_vars/all.yml`:

```yaml
k8s_service_groups:
  network:
    - name: calico
      enabled: true
      description: Primary CNI when cni_prime is calico.
    - name: sriov
      enabled: false
      requires: [multus, whereabouts]
      description: SR-IOV device plugin and NADs.
```

Normal full install runs services where `enabled: true`. To skip or add a service, change its `enabled` value in `group_vars/all.yml`.

Example: run only CoreDNS after the cluster exists by overriding the enabled catalog:

```shell
ansible-playbook -i inventory.ini site.yml \
  -e '{"k8s_service_groups":{"base":[],"ha":[],"cluster":[],"network":[{"name":"coredns","enabled":true}],"addons":[],"observability":[],"tuning":[]}}'
```

Example: update resource values for kubeadm-created workloads after editing `group_vars/resources.yml`:

```shell
ansible-playbook -i inventory.ini site.yml \
  -e '{"k8s_service_groups":{"base":[],"ha":[],"cluster":[],"network":[],"addons":[],"observability":[],"tuning":[{"name":"k8s_tuning","enabled":true}]}}'
```

Example: run selected exporters after the cluster exists:

```shell
ansible-playbook -i inventory.ini site.yml \
  -e '{"k8s_service_groups":{"base":[],"ha":[],"cluster":[],"network":[],"addons":[],"observability":[{"name":"cert_exporter","enabled":true},{"name":"snmp_exporter","enabled":true},{"name":"haproxy_exporter","enabled":true}],"tuning":[]}}'
```

`requires` is documentation for operators. `ip_pools_exporter` also requires `multus_sriov: true` in its role conditions.

## 7. Deploy Full Cluster

Run from `k8s_auto/`:

```shell
ansible-playbook -i inventory.ini site.yml
```

Warning: bootstrap tasks reset Kubernetes, CNI, kubeconfig, and etcd state on target nodes. Run only on nodes intended for this cluster.

## 8. Enable Or Disable Extra Services

Extra services are selected at the top of `group_vars/all.yml` and run at the end of `site.yml` on the bootstrap master when `enabled: true`. Fluent Bit, Local Path Provisioner, and Elasticsearch are registered there by default:

```yaml
k8s_enabled_extra_services:
  - name: fluentbit
    role: services/fluentbit
    enabled: true
  - name: local_path_provisioner
    role: services/local_path_provisioner
    enabled: true
  - name: elasticsearch
    role: services/elasticsearch
    enabled: true
    depends_on:
      - local_path_provisioner
```

Run the single playbook from `k8s_auto/`:

```shell
ansible-playbook -i inventory.ini site.yml
```

For Fluent Bit, adjust the small deployment variable set in `group_vars/services.yml`: namespace, cluster name, Elasticsearch endpoint/credential, host paths, and `fluentbit_profiles`. Native Fluent Bit config templates live under `roles/services/fluentbit/templates/conf/`.

For Local Path Provisioner, adjust `local_path_default_path`, `local_path_storage_class_name`, and related `local_path_*` values in `group_vars/services.yml`.

For Elasticsearch, label target nodes before applying:

```shell
kubectl label node <master-node> es-role=master
kubectl label node <data-node> es-role=data
kubectl label node <client-node> es-role=client
```

Elasticsearch depends on Local Path Provisioner for its data and log PVC StorageClasses. Keep `local_path_provisioner` enabled and before `elasticsearch`; the role waits for the provisioner rollout before applying Elasticsearch manifests. Elasticsearch renders separate config maps for master, data, and client node sets while sharing `elasticsearch-log4j2` and `jvm-config`. After the Elasticsearch StatefulSets are ready, a short-lived `elasticsearch-post-install` Job sets the `kibana_system` password from `elasticsearch_kibana_auth`; Kibana and the exporter are applied only after that job succeeds.

## 9. Add Future Extra Services

Create a new role under `roles/services/`, for example:

```text
roles/services/k8s_ingress_nginx/
  tasks/main.yml
  templates/
  defaults/main.yml
```

Add it to `k8s_enabled_extra_services` in `group_vars/all.yml`:

```yaml
k8s_enabled_extra_services:
  - name: ingress_nginx
    role: services/k8s_ingress_nginx
    enabled: true
```

Then run:

```shell
ansible-playbook -i inventory.ini site.yml
```

To disable one extra service, set `enabled: false`. To disable all extra services, override the list:

```yaml
k8s_enabled_extra_services: []
```
