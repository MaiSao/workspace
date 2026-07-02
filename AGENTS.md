# Repository Guidelines

## Project Structure & Module Organization

This repository contains an Ansible-based Kubernetes installer under `k8s_auto/`.

- `k8s_auto/site.yml`: main playbook entry point.
- `k8s_auto/inventory.ini`: target host inventory; define `master` and worker hosts here.
- `k8s_auto/group_vars/`: three operator files: `all.yml` for cluster/environment settings, `images.yml` for image names and pull lists, and `services.yml` for install phases, manifests, extra services, and static pod resources.
- `k8s_auto/roles/common/`, `containerd/`, `k8s_ha/`, `kubeadm_*`, `kubeconfig/`, and `k8s_patch/`: active base install roles.
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
- Added `k8s_auto/extra-services.yml` for future service roles. It uses `k8s_enabled_extra_services`, which is empty by default, so the current full install behavior is unchanged. Add future roles under `roles/services/`, add entries to `k8s_enabled_extra_services`, then run `ansible-playbook -i inventory.ini extra-services.yml`.

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

- Added `roles/services/kubelet_csr_approver` as an extra service role.
- Converted the source manifest from `k8s_extends/kubelet-csr-approver/kubelet-csr-approver.yaml` into a Jinja template using `kubelet_csr_approver_image`.
- Added `kubelet_csr_approver_image` to `group_vars/images.yml`.
- Registered the service in `group_vars/services.yml` under `k8s_enabled_extra_services`, so it runs with `ansible-playbook -i inventory.ini extra-services.yml`.

## Change Log For Group Vars Restructure

- Consolidated `k8s_auto/group_vars/` into three active files: `all.yml`, `images.yml`, and `services.yml`.
- Replaced `image_file.yml` with `images.yml`; image variables and pull lists now live there.
- Moved manifest template lists and control-plane static pod resource values into `services.yml`.
- Removed the old `master.yml`; its resource values now live in `services.yml`.
- Updated `site.yml`, `extra-services.yml`, `README.md`, and this guide to reference the new file layout.
