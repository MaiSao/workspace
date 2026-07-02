# Repository Guidelines

## Project Structure & Module Organization

This repository contains an Ansible-based Kubernetes installer under `k8s_auto/`.

- `k8s_auto/site.yml`: main playbook entry point.
- `k8s_auto/inventory.ini`: target host inventory; define `master` and worker hosts here.
- `k8s_auto/group_vars/`: operator files: `all.yml` for cluster/environment settings, `images.yml` for image names and pull lists, `services.yml` for install phases/manifests/extra services, and `resources.yml` for requests/limits.
- `k8s_auto/roles/common/`, `containerd/`, `k8s_ha/`, `kubeadm_*`, `kubeconfig/`, `k8s_resources/`, and `k8s_patch/`: active base install roles.
- `k8s_auto/roles/services/`: active Kubernetes service roles such as CNI and add-ons.

There is currently no dedicated test directory.

## Build, Test, and Development Commands

Run commands from `k8s_auto/`:

```bash
ansible-playbook -i inventory.ini site.yml
```

Runs the full Kubernetes installation. Use only on intended cluster nodes because bootstrap tasks reset Kubernetes state.

```bash
ansible-playbook -i inventory.ini site.yml --list-tasks
ansible-playbook -i inventory.ini site.yml --list-tags
```

Inspect execution order and available tags without running changes.

```bash
ansible-playbook -i inventory.ini site.yml --syntax-check
```

Validate playbook syntax before deployment.

## Coding Style & Naming Conventions

Use two-space YAML indentation. Keep task names descriptive and action-oriented, for example `generate containerd config file`. Prefer snake_case for variables, but preserve existing Kubernetes-style names where already used, such as `localAPIEndpointAddress`.

Internal runtime facts use the existing `__name` pattern, for example `__bootstrap_dir`. Template files should include the service and version when relevant, such as `metric-server-v0.8.0.yaml.j2`.

## Testing Guidelines

No automated test framework is configured. At minimum, run `--syntax-check` and `--list-tasks` before deploying. For risky role changes, test against disposable nodes or a lab inventory first. Verify generated logs under `/root/kubebootstrap/logs/` on target hosts.

## Commit & Pull Request Guidelines

No local Git history was available to infer commit style. Use short imperative commit messages, for example `Split CNI install tasks` or `Add kubeadm syntax checks`.

Pull requests should include the deployment scenario tested, inventory shape, changed variables, and any operational risk. For Kubernetes manifest changes, mention the affected component and version.

## Security & Configuration Tips

Do not commit real host passwords, registry credentials, or production IPs. Review `group_vars/all.yml` before every run, especially registry, repo, VIP, CNI, and destructive bootstrap settings.

## Change Log For Dynamic Services

- Added `k8s_auto/group_vars/services.yml` as a dynamic service catalog. The default service list now matches the split roles: common, containerd, HA, kubeadm prepare/control-plane/join, kubeconfig, CNI, add-ons, and patching.
- Updated `k8s_auto/site.yml` to load `group_vars/services.yml` after the existing image and cluster variables and to run the split roles.
- Earlier service-gating work in `roles/kubernetes-optimized/tasks/main.yml` was superseded by the split-role `site.yml`; the old unused role has now been removed.
- Added tags matching service names for easier inspection or manual runs. Normal full install still uses `ansible-playbook -i inventory.ini site.yml` with no tag requirement.
- Join command generation now lives in `kubeadm_control_plane` and can run when `kubeadm_join` is selected without `kubeadm_control_plane`.
- To skip a service, remove it from `k8s_default_services` in `group_vars/services.yml` or override `k8s_install_services` with `-e` at runtime.
- Added `k8s_auto/extra-services.yml` for optional service roles. It uses `k8s_enabled_extra_services`, currently including Fluent Bit, while the normal full install path remains `site.yml`.

## Change Log For Multi-Role Split

- Split the active install flow out of the old monolithic role into role-owned phases: `common`, `containerd`, `k8s_ha`, `kubeadm_prepare`, `kubeadm_control_plane`, `kubeadm_join`, `kubeconfig`, `services/k8s_cni`, `services/k8s_addons`, and `k8s_patch`.
- Updated `k8s_auto/site.yml` to a single `hosts: all` play that lists each split role once. Role-level `when` checks restrict first-master, master-only, worker, and optional-service work.
- Updated `k8s_auto/group_vars/services.yml` service names to match the new roles. Default full install still runs when using `ansible-playbook -i inventory.ini site.yml`.
- Split the old bootstrap responsibilities into `common-bootstrap.sh.j2`, `containerd-bootstrap.sh.j2`, and `k8s-ha-bootstrap.sh.j2`. The destructive common bootstrap script runs only when `common_bootstrap_enabled: true`.
- Moved CNI and add-on manifest rendering into their owning service roles so templates live with the role that applies them.
- Removed the old unused `roles/kubernetes-optimized/` directory after the active `site.yml` moved fully to split roles.

## Change Log For Unused File Cleanup

- Removed unused active service templates that were not referenced by the manifest lists now kept in `group_vars/services.yml`: `etcd-backup-cronjob.yaml.j2`, `etcd-rotate-cronjob.yaml.j2`, `metric-server-v0.6.1.yaml.j2`, and `calico-v3.29.1.yaml.j2`.
- Removed now-unused image variables for deleted templates: `etcd_legacy_backup_image` and `metrics_server_v0_6_image`.
- Removed the old unused `k8s_auto/roles/kubernetes-optimized/` role directory. Active installs use the split roles in `site.yml`.

## Change Log For Single-Play Site

- Simplified `k8s_auto/site.yml` to one play named `Install Kubernetes cluster` with `hosts: all`.
- Listed every active role once so a role cannot be invoked multiple times on the same node by the playbook structure.
- Added/kept role-level host guards so master-only roles, first-master roles, worker joins, add-ons, and patching run only where intended.

## Change Log For Kubelet CSR Approver

- Moved kubelet CSR approver into the built-in `services/k8s_addons` flow.
- Converted the source manifest from `k8s_extends/kubelet-csr-approver/kubelet-csr-approver.yaml` into `roles/services/k8s_addons/templates/kubelet-csr-approver.yaml.j2` using `kubelet_csr_approver_image`.
- Added `kubelet_csr_approver_image` to `group_vars/images.yml`.
- Added `kubelet-csr-approver.yaml.j2` to `add_on_self`, so it runs with the normal `addons` service in `site.yml`.

## Change Log For Kyverno

- Added Kyverno v1.14.4 to the built-in `services/k8s_addons` flow using manifests from `k8s_extends/kyverno/`.
- Converted Kyverno images to variables in `group_vars/images.yml` and Kyverno resources to `group_vars/resources.yml`.
- Added Kyverno ClusterPolicy templates with Jinja raw blocks so Kyverno expressions are preserved during Ansible rendering.

## Change Log For Etcd Client Tools

- Added master-only `etcdctl` and `etcdutl` installation to the `common` role using `roles/common/files/etcd-v3.5.15-linux-amd64.tar.gz`.
- Added `/etc/profile.d/etcdctl.sh` with local static-pod etcd certificate defaults.
- This installs client tools only; it does not start, stop, enable, or disable etcd.

## Change Log For Exporters

- Added optional `services/k8s_exporters` role for cert-exporter, ip-pools-exporter, snmp-exporter, and snmp-switch-exporter.
- Added per-exporter switches under `k8s_exporters` in `group_vars/services.yml`; the role runs only when `exporters` is in `k8s_install_services`.
- SNMP exporter installs and starts `snmpd` on target nodes, then deploys its DaemonSet with `snmp.yml` mounted from `/etc/snmp_exporter`.
- cert-exporter and snmp-switch-exporter are scheduled only on master/control-plane nodes; ip-pools-exporter is also gated by `multus_sriov: true`.
- Added optional HAProxy and Keepalived host-service exporters for master nodes, installed from the OS repository and managed with systemd units.

## Change Log For Fluent Bit

- Added `services/fluentbit` as an extra service role installed by `extra-services.yml`.
- Converted the source Fluent Bit manifests from `k8s_extends/fluentbitv4.2.2/hla-mano/` into templates while keeping native Fluent Bit `.conf` files under `roles/services/fluentbit/templates/conf/`.
- Added minimal deployment variables for namespace, cluster name, Elasticsearch endpoint/credential, host paths, and `fluentbit_profiles`.
- Added `fluentbit_image` and `k8s_resources.fluentbit`; ConfigMap rendering supports profile-based input blocks without YAML-encoding every Fluent Bit directive.

## Change Log For Local Path Provisioner

- Added `services/local_path_provisioner` as an extra service role installed by `extra-services.yml`.
- Converted Rancher local-path-provisioner v0.0.36 into a template with configurable namespace, StorageClass name, default host path, reclaim policy, volume binding mode, and default-class flag.
- Added `local_path_provisioner_image` and `local_path_helper_image`; both render through the configured registry prefix.
- Elasticsearch uses this provisioner for its data and log StorageClasses, so keep this extra service enabled and ordered before `services/elasticsearch`.

## Change Log For Elasticsearch

- Added `services/elasticsearch` as an extra service role installed by `extra-services.yml`.
- Converted the `k8s_extends/elasticsearchv8.19` reference stack into templates for Elasticsearch, Kibana, Elasticsearch exporter, storage classes, secrets, and services.
- Split `elasticsearch.yml` into per-node-set ConfigMaps for master, data, and client while keeping `elasticsearch-log4j2` and `jvm-config` shared.
- Added default 3/3/3 master/data/client topology with role-specific heap, resources, PVC sizes, and tuning values based on the reference configuration.
- Added an explicit dependency check and rollout wait for `local_path_provisioner`; Elasticsearch StorageClasses now use `local_path_provisioner_name`.
- Added a privileged `sysctl` init container for Elasticsearch pods to set `vm.max_map_count=262144` and `fs.file-max=50000000`.
- Split Elasticsearch apply order so core Elasticsearch starts first, then the role sets the `kibana_system` password through the Elasticsearch security API before applying Kibana and the exporter.
- Replaced the in-pod `kubectl exec` password setup with a short-lived `elasticsearch-post-install` Job using `elasticsearch_setup_image`; the role waits for all enabled Elasticsearch StatefulSets, then the job, then Kibana/exporter rollouts.
- Reduced repeated Elasticsearch node-set config by deriving ConfigMap and headless service names from the node-set name in templates.

## Change Log For Script Error Handling

- Added `set -Eeuo pipefail` and Bash execution to shell tasks that run generated scripts or command pipelines.
- Added error traps to generated bootstrap/deploy scripts so failures print the failed line and command before Ansible stops.
- Preserved intentional skip behavior where `ignore_errors` is explicitly set, such as kubeconfig creation for missing local users.

## Change Log For SR-IOV Variables

- Replaced full SR-IOV generated object lists with compact operator inputs: `sriov_pf_mappings`, `sriov_bond_groups`, and `sriov_bond_networks`.
- Updated `sriov_configMap.yaml.j2` to build the device plugin `resourceList` from PF mappings and selector defaults.
- Updated `whereabouts-nad-sriov-bond.yaml.j2` to build direct SR-IOV and bond NetworkAttachmentDefinitions from the compact variables.
- Fixed SR-IOV apply logic so those manifests run only when `multus_sriov | bool` is true.

## Change Log For Macvlan Variables

- Added `multus_macvlan` as a separate switch for Whereabouts-backed macvlan NetworkAttachmentDefinitions.
- Added compact macvlan inputs in `group_vars/services.yml`: `macvlan_defaults` and self-contained `macvlan_networks`.
- Kept macvlan network fields explicit in each item with `master_interface`, `ip_range`, `gateway`, and optional allocation range values.
- Added `whereabouts-nad-macvlan.yaml.j2` so the CNI role generates the full macvlan NAD manifests from those variables.

## Change Log For Resource Management

- Added `k8s_auto/group_vars/resources.yml` for static pod, CNI, add-on, CoreDNS, and kube-proxy requests/limits.
- Added `roles/k8s_resources` to apply `kubectl set resources` for kubeadm-created CoreDNS and kube-proxy workloads.
- Updated add-on and CNI templates to render container resources from `k8s_resources`.
- Updated `k8s_patch` to read static pod resources from `k8s_static_pod_patches` and avoid duplicating static pod command arguments on rerun.

## Change Log For Group Vars Restructure

- Consolidated `k8s_auto/group_vars/` into focused operator files: `all.yml`, `images.yml`, `services.yml`, and `resources.yml`.
- Replaced `image_file.yml` with `images.yml`; image variables and pull lists now live there.
- Moved manifest template lists into `services.yml`; resource values now live in `resources.yml`.
- Removed the old `master.yml`; its resource values now live in `services.yml`.
- Updated `site.yml`, `extra-services.yml`, `README.md`, and this guide to reference the new file layout.
