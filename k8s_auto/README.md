---
Title: Install Kubernetes guide
---

## Overview

This directory contains an Ansible-based Kubernetes installer. The main entry point is `site.yml`, a single play that targets all nodes and lists each split role once. Each role decides what to do from host group membership and `group_vars/services.yml`.

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

- `group_vars/all.yml`: Kubernetes version, networking, registry, repo, VIP, audit, etcd, containerd, and bootstrap settings.
- `group_vars/images.yml`: image names and image pull checklists.
- `group_vars/services.yml`: install phase selection, manifest template lists, and extra service catalog.
- `group_vars/resources.yml`: resource requests/limits for static pods, CNI, add-ons, CoreDNS, and kube-proxy.

## 5. Role Layout

The installer is split by responsibility:

```text
roles/common/                 OS repo, packages, kernel modules, sysctl, hosts, kubelet bootstrap, etcd client tools
roles/containerd/             containerd package, registry config, crictl, service start
roles/k8s_ha/                 HAProxy, Keepalived, API VIP, health check
roles/kubeadm_prepare/        audit policy and kubeadm config rendering
roles/kubeadm_control_plane/  kubeadm init and join command generation
roles/kubeadm_join/           worker/control-plane join logic
roles/kubeconfig/             admin kubeconfig setup for master users
roles/services/k8s_cni/       Calico, Multus, Whereabouts, SR-IOV, CoreDNS
roles/services/k8s_addons/    metrics-server, kube-state-metrics, kubelet CSR approver, Kyverno, etcd jobs
roles/services/k8s_exporters/ optional cert, IP pool, SNMP, and SNMP switch exporters
roles/services/fluentbit/     optional Fluent Bit extra service for cluster, host, and application logs
roles/services/local_path_provisioner/ optional Rancher local-path storage provisioner
roles/services/elasticsearch/ optional Elasticsearch, Kibana, and Elasticsearch exporter stack
roles/k8s_resources/          kubectl resource updates for kubeadm-created workloads
roles/k8s_patch/              static pod resource/argument patching
```

`site.yml` runs these roles once per node in the order shown by the playbook. Role-level `when` checks restrict master-only work, first-master work, worker joins, and optional services.

## 6. Service Catalog

Default install phases are defined in `group_vars/services.yml`:

```yaml
k8s_default_services:
  - common
  - containerd
  - k8s_ha
  - kubeadm_prepare
  - kubeadm_control_plane
  - kubeconfig
  - cni
  - kubeadm_join
  - addons
  - k8s_resources
  - k8s_patch
```

Normal full install uses all default services. To skip a built-in phase, remove it from `k8s_default_services` or override `k8s_install_services` at runtime.

Example: run only CNI after the cluster exists:

```shell
ansible-playbook -i inventory.ini site.yml -e 'k8s_install_services=["cni"]'
```

Example: update resource values for kubeadm-created workloads after editing `group_vars/resources.yml`:

```shell
ansible-playbook -i inventory.ini site.yml -e 'k8s_install_services=["k8s_resources","k8s_patch"]'
```

Example: run selected exporters after the cluster exists:

```shell
ansible-playbook -i inventory.ini site.yml \
  -e 'k8s_install_services=["exporters"]' \
  -e '{"k8s_exporters":{"cert":{"enabled":true},"ip_pools":{"enabled":false},"snmp":{"enabled":true},"snmp_switch":{"enabled":true}}}'
```

`ip_pools` is applied only when both `k8s_exporters.ip_pools.enabled: true` and `multus_sriov: true`.

## 7. Deploy Full Cluster

Run from `k8s_auto/`:

```shell
ansible-playbook -i inventory.ini site.yml
```

Warning: bootstrap tasks reset Kubernetes, CNI, kubeconfig, and etcd state on target nodes. Run only on nodes intended for this cluster.

## 8. Run Extra Services

Extra services are installed by `extra-services.yml` and do not run during the normal full cluster install. Fluent Bit, Local Path Provisioner, and Elasticsearch are registered there by default:

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

Run from `k8s_auto/`:

```shell
ansible-playbook -i inventory.ini extra-services.yml
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

Add it to `group_vars/services.yml`:

```yaml
k8s_enabled_extra_services:
  - name: ingress_nginx
    role: services/k8s_ingress_nginx
    enabled: true
```

Then run:

```shell
ansible-playbook -i inventory.ini extra-services.yml
```

To disable all extra services, override the list:

```yaml
k8s_enabled_extra_services: []
```
