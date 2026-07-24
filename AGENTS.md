# Repository Guidelines

## Project Structure & Module Organization

This repository contains an Ansible-based Kubernetes installer under `k8s_auto/`
and a separated post-install checklist under `k8s_checklist/`.

- `k8s_auto/site.yml`: main playbook entry point.
- `k8s_auto/inventory.ini`: target host inventory; define `k8s_master` and `k8s_worker` hosts here.
- `k8s_auto/group_vars/`: operator files: `all.yml` for cluster/infrastructure settings, `services.yml` for service switches and configuration, `images.yml` for image names and pull lists, and `resources.yml` for requests/limits.
- `k8s_auto/roles/`: all orchestration, base, CNI, add-on, exporter, and extra-service roles live directly at this single role level.
- `k8s_checklist/playbook.yml`: independent checklist entry point.
- `k8s_checklist/inventory.ini`: independent checklist inventory.
- `k8s_checklist/group_vars/checklist.yml`: user-supplied checklist inputs and rules.
- `k8s_checklist/roles/checklist/`: checklist execution engine.

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

Run commands from `k8s_checklist/`:

```bash
ansible-playbook -i inventory.ini playbook.yml
ansible-playbook -i inventory.ini playbook.yml --syntax-check
ansible-playbook -i inventory.ini playbook.yml --list-tasks
```

Runs or inspects the separated post-install checklist. The checklist uses its
own inventory and `group_vars/checklist.yml`; do not import installer vars.

## Coding Style & Naming Conventions

Use two-space YAML indentation. Keep task names descriptive and action-oriented, for example `generate containerd config file`. Prefer snake_case for variables, but preserve existing Kubernetes-style names where already used, such as `localAPIEndpointAddress`.

Internal runtime facts use the existing `__name` pattern, for example `__bootstrap_dir`. Template files should include the service and version when relevant, such as `metric-server-v0.8.0.yaml.j2`.

## Testing Guidelines

No automated test framework is configured. At minimum, run `--syntax-check` and `--list-tasks` before deploying. For risky role changes, test against disposable nodes or a lab inventory first. Verify generated installer logs under `/root/k8s_install/logs/` on target hosts.

## Commit & Pull Request Guidelines

No local Git history was available to infer commit style. Use short imperative commit messages, for example `Split CNI install tasks` or `Add kubeadm syntax checks`.

Pull requests should include the deployment scenario tested, inventory shape, changed variables, and any operational risk. For Kubernetes manifest changes, mention the affected component and version.

## Security & Configuration Tips

Do not commit real host passwords, registry credentials, or production IPs. Review `group_vars/all.yml` before every run, especially registry, repo, VIP, CNI, and destructive bootstrap settings.

## Change Log For Dynamic Services

- Service switches live at the top of `k8s_auto/group_vars/services.yml`; the explicit role list in `site.yml` defines deterministic installation order.
- Updated `k8s_auto/site.yml` to load `group_vars/services.yml` after the existing image and cluster variables and to run the split roles.
- Earlier service-gating work in `roles/kubernetes-optimized/tasks/main.yml` was superseded by the split-role `site.yml`; the old unused role has now been removed.
- Added tags matching service names for easier inspection or manual runs. Normal full install still uses `ansible-playbook -i inventory.ini site.yml` with no tag requirement.
- Join command generation now lives in the unified `kubeadm` role.
- To skip or enable a service, change its boolean in `k8s_services` or `k8s_extra_services` at the top of `group_vars/services.yml`. Execution order and host guards remain explicit in `site.yml`.
- Extra service selection and detailed extra-service configuration live in `group_vars/services.yml`.
- Extra service roles are listed explicitly in `site.yml` with enable and bootstrap-master conditions; `site.yml` remains the single entry point.

## Change Log For Multi-Role Split

- Split the active install flow into service-level roles: `common`, `containerd`, `haproxy`, `keepalived`, `kubeadm`, `calico`, `multus`, `whereabouts`, `sriov`, `macvlan`, `coredns`, `metrics_server`, `kube_state_metrics`, `kubelet_csr_approver`, `kyverno`, `etcd_jobs`, individual exporter roles, and `k8s_tuning`.
- Updated `k8s_auto/site.yml` to a single play for `k8s_cluster`; every component role is listed explicitly in deterministic order with enable and host guards.
- Updated `k8s_auto/group_vars/services.yml` service names to match the new roles. Default full install still runs when using `ansible-playbook -i inventory.ini site.yml`.
- Split the old bootstrap responsibilities into explicit `common` role tasks, `containerd-bootstrap.sh.j2`, `roles/haproxy/templates/haproxy.cfg.j2`, and `roles/keepalived/templates/keepalived.conf.j2`. Destructive common reset tasks run only when `common_bootstrap_enabled: true` and `__rerun_bootstrap` is defined.
- Moved CNI and add-on manifest rendering into their owning service roles so templates live with the role that applies them. Legacy bundle roles remain in the tree for reference but are no longer called by `site.yml`.
- Removed the old unused `roles/kubernetes-optimized/` directory after the active `site.yml` moved fully to split roles.

## Change Log For Unused File Cleanup

- Removed unused active service templates that were not referenced by the manifest lists now kept in `group_vars/services.yml`: `etcd-backup-cronjob.yaml.j2`, `etcd-rotate-cronjob.yaml.j2`, `metric-server-v0.6.1.yaml.j2`, and `calico-v3.29.1.yaml.j2`.
- Removed now-unused image variables for deleted templates: `etcd_legacy_backup_image` and `metrics_server_v0_6_image`.
- Removed the old unused `k8s_auto/roles/kubernetes-optimized/` role directory. Active installs use the split roles in `site.yml`.

## Change Log For Single-Play Site

- Simplified `k8s_auto/site.yml` to one play named `Install Kubernetes cluster` targeting `k8s_cluster`.
- Kept `site.yml` role-only and listed every enabled component role directly in deterministic order.
- Added/kept role-level host guards so master-only roles, first-master roles, worker joins, add-ons, and patching run only where intended.

## Change Log For Kubelet CSR Approver

- Moved kubelet CSR approver into the built-in `kubelet_csr_approver` flow.
- Converted the source manifest from `k8s_extends/kubelet-csr-approver/kubelet-csr-approver.yaml` into `roles/kubelet_csr_approver/templates/kubelet-csr-approver.yaml.j2` using `kubelet_csr_approver_image`.
- Added `kubelet_csr_approver_image` to `group_vars/images.yml`.
- Added `kubelet-csr-approver.yaml.j2` to its own service role, so it runs with `kubelet_csr_approver` in `site.yml`.

## Change Log For Kyverno

- Added Kyverno v1.14.4 to the built-in `kyverno` flow using manifests from `k8s_extends/kyverno/`.
- Converted Kyverno images to variables in `group_vars/images.yml` and Kyverno resources to `group_vars/resources.yml`.
- Added Kyverno ClusterPolicy templates with Jinja raw blocks so Kyverno expressions are preserved during Ansible rendering.

## Change Log For Etcd Client Tools

- Added master-only `etcdctl` and `etcdutl` installation to the `common` role using `roles/common/files/etcd-v3.5.15-linux-amd64.tar.gz`.
- Added `/etc/profile.d/etcdctl.sh` with local static-pod etcd certificate defaults.
- This installs client tools only; it does not start, stop, enable, or disable etcd.

## Change Log For Exporters

- Split exporter installation into individual service roles: `cert_exporter`, `ip_pools_exporter`, `snmp_exporter`, `snmp_switch_exporter`, `haproxy_exporter`, and `keepalived_exporter`.
- Exporters are enabled from `k8s_services`; host exporter config lives in `group_vars/services.yml`.
- SNMP exporter installs and starts `snmpd` on target nodes, then deploys its DaemonSet with `snmp.yml` mounted from `/etc/snmp_exporter`.
- cert-exporter and snmp-switch-exporter are scheduled only on master/control-plane nodes; ip-pools-exporter is also gated by `multus_sriov: true`.
- Added optional HAProxy and Keepalived host-service exporters for master nodes, installed from the OS repository and managed with systemd units.

## Change Log For Fluent Bit

- Added `fluentbit` as an extra service role installed by the `site.yml` extra service loop.
- Converted the source Fluent Bit manifests from `k8s_extends/fluentbitv4.2.2/hla-mano/` into templates while keeping native Fluent Bit `.conf` files under `roles/fluentbit/templates/conf/`.
- Added minimal deployment variables for namespace, cluster name, Elasticsearch endpoint/credential, host paths, and `fluentbit_profiles`.
- Added `fluentbit_image` and `k8s_resources.fluentbit`; ConfigMap rendering supports profile-based input blocks without YAML-encoding every Fluent Bit directive.

## Change Log For Local Path Provisioner

- Added `local_path_provisioner` as an extra service role installed by the `site.yml` extra service loop.
- Converted Rancher local-path-provisioner v0.0.36 into a template with configurable namespace, StorageClass name, default host path, reclaim policy, volume binding mode, and default-class flag.
- Added `local_path_provisioner_image` and `local_path_helper_image`; both render through the configured registry prefix.
- Elasticsearch uses this provisioner for its data and log StorageClasses, so keep this extra service enabled and ordered before `elasticsearch`.

## Change Log For Elasticsearch

- Added `elasticsearch` as an extra service role installed by the `site.yml` extra service loop.
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

## Change Log For Global Runtime Vars And Repositories

- Moved bootstrap session setup to `site.yml` so all roles can use `__bootstrap_dir`, `__session_time`, and shared log paths without depending on the `common` role.
- Kept `__bootstrap_dir` and `__registry_prefix` in `group_vars/all.yml` as global operator variables used by multiple roles and templates.
- Replaced hardcoded yum/dnf repository blocks with the `os_repositories` list from `group_vars/all.yml`.
- Reordered kubeadm tasks so additional control-plane nodes join before kubeconfig is distributed to configured master users.

## Change Log For Explicit Service Plan

- Service selection uses compact boolean maps in `group_vars/services.yml`.
- Execution order and host guards are explicit on every role entry in `site.yml`.
- The installation summary displays enabled and disabled service names from those maps.
- Replaced the old `common-bootstrap.sh.j2` script with named Ansible tasks inside `roles/common/tasks/main.yml` so reset, hosts, repository, kernel, package, kubelet, NetworkManager, and etcd client tool steps are visible independently.
- Standardized install/bootstrap script logging for containerd, kubeadm init, kubeadm join, and join-command regeneration. The common role now uses named Ansible tasks instead of a bootstrap script.
- Script-running tasks now capture stderr with stdout into `/root/k8s_install/logs/` and print the last 120 log lines on failure.
- Runtime scripts and service units are intentionally not changed for Ansible logging behavior.

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
- Added `roles/k8s_tuning` to apply `kubectl set resources` for kubeadm-created CoreDNS and kube-proxy workloads.
- Updated add-on and CNI templates to render container resources from `k8s_resources`.
- Updated `k8s_tuning` to read static pod resources from `k8s_static_pod_patches` and avoid duplicating static pod command arguments on rerun.
- Removed the old `k8s_resources` and `k8s_patch` roles after merging them into `k8s_tuning`.

## Change Log For Group Vars Restructure

- Consolidated `k8s_auto/group_vars/` into focused operator files: `all.yml`, `images.yml`, `services.yml`, and `resources.yml`.
- `all.yml` starts with commonly changed cluster, network, HA, registry, repository, path, and bootstrap settings; optional Kubernetes defaults and derived values follow.
- `services.yml` starts with compact built-in and extra-service boolean maps, followed by operator configuration and advanced manifest defaults.
- Replaced `image_file.yml` with `images.yml`; image variables and pull lists now live there.
- Moved manifest template lists into `services.yml`; resource values now live in `resources.yml`.
- Removed the old `master.yml`; its resource values now live in `services.yml`.
- Updated `site.yml`, `README.md`, and this guide to reference the new file layout.

## Change Log For Checklist Playbook

- Moved checklist out of `k8s_auto` into the sibling `k8s_checklist/` directory so installation and verification flows are independent.
- Added `k8s_checklist/playbook.yml` as the standalone checklist entry point.
- Added `k8s_checklist/group_vars/checklist.yml` as the single checklist input and rule set. Operators push or edit expected parameters here after installation.
- Checklist runs host service checks, host config file checks, Kubernetes core pod health checks, object existence checks, rollout checks, JSONPath parameter assertions, CNI NAD checks, Elasticsearch target label checks, and selected extra-service parameter checks.
- Each checklist run writes the effective comparison parameters to `/root/kubebootstrap/checklist/install-parameters.yml` on the bootstrap master.
