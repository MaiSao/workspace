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
- `group_vars/services.yml`: install phase selection, manifest template lists, extra service catalog, and static pod resources.

## 5. Role Layout

The installer is split by responsibility:

```text
roles/common/                 OS repo, packages, kernel modules, sysctl, hosts, kubelet bootstrap
roles/containerd/             containerd package, registry config, crictl, service start
roles/k8s_ha/                 HAProxy, Keepalived, API VIP, health check
roles/kubeadm_prepare/        audit policy and kubeadm config rendering
roles/kubeadm_control_plane/  kubeadm init and join command generation
roles/kubeadm_join/           worker/control-plane join logic
roles/kubeconfig/             admin kubeconfig setup for master users
roles/services/k8s_cni/       Calico, Multus, Whereabouts, SR-IOV, CoreDNS
roles/services/k8s_addons/    metrics-server, kube-state-metrics, etcd jobs
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
  - kubeadm_join
  - cni
  - addons
  - k8s_patch
```

Normal full install uses all default services. To skip a built-in phase, remove it from `k8s_default_services` or override `k8s_install_services` at runtime.

Example: run only CNI after the cluster exists:

```shell
ansible-playbook -i inventory.ini site.yml -e 'k8s_install_services=["cni"]'
```

## 7. Deploy Full Cluster

Run from `k8s_auto/`:

```shell
ansible-playbook -i inventory.ini site.yml
```

Warning: bootstrap tasks reset Kubernetes, CNI, kubeconfig, and etcd state on target nodes. Run only on nodes intended for this cluster.

## 8. Add Future Extra Services

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

Current extra services in `group_vars/services.yml`:

```yaml
k8s_enabled_extra_services:
  - name: kubelet_csr_approver
    role: services/kubelet_csr_approver
    enabled: true
```

This installs the kubelet CSR approver from `roles/services/kubelet_csr_approver`.
