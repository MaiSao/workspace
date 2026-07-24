# Kubernetes PAT Automation

`k8s_pat/` automates a production acceptance test (PAT) subset for Kubernetes.
It is independent from `../k8s_auto/` and `../k8s_checklist/`.

The current profile defines all 88 PAT IDs from `PAT_CASES.md`. Production
read-only checks run directly, optional installer features are gated by
`pat_installed_services`/`pat_features`, and synthetic, chaos, lab or manual
evidence cases report `N/A` until their explicit safety gate is enabled.

The runner records every case as `PASS`, `FAILED` or `N/A`, including the reason
and the recommendation/remediation text. Reports are written on the bootstrap
master under `/root/k8s_pat/reports/` as Markdown and JSON.

Before running cases, the runner discovers live usage such as application
namespaces, PVC StorageClasses, NetworkAttachmentDefinition references, HPA,
PDB, Ingress and Gateway objects. Cases use this signal to distinguish
"feature installed" from "feature actually used".

The report has two summaries:

- Case summary: one status per PAT ID, using `FAILED > PASS > N/A` precedence.
- Assertion summary: every executed target, so host-scope checks show one row
  per node.

For multi-node clusters, `host`, `master`, `worker` and `all` scoped cases run
against every matching inventory host. Cluster-scoped cases run once through the
Kubernetes API but validate expected master/worker counts, daemon coverage and
live object usage across the whole cluster where applicable.

## Configure

Edit:

```text
k8s_pat/inventory.ini
k8s_pat/group_vars/pat.yml
```

Use one-level `k8s_master` and `k8s_worker` group names for PAT inventories.
The playbook targets both groups directly with `k8s_master:k8s_worker`.

Important switches:

- `pat_installed_services`: mirrors the current `../k8s_auto/group_vars/services.yml`
  plan so cases follow the installed feature set.
- `pat_features`: declares whether optional capabilities are in the approved
  design, for example HPA, CSI, Gateway/Ingress, WAF or observability backend.
- `pat_enable_prod_synthetic`: enables bounded synthetic tests that create PAT
  resources.
- `pat_enable_chaos`: enables controlled resilience tests. Keep this disabled
  on production unless there is an approved maintenance window.
- `pat_enable_lab_dr`: enables lab-only disaster recovery evidence cases.
- `pat_record_catalog_gap_cases`: normally `false` because the profile already
  defines all catalog IDs; turn it on only after adding new IDs to `PAT_CASES.md`
  before implementing their command logic.

When a feature is not used, its case is reported as `N/A` with the configured
reason and recommendation. Do not mark a case N/A only because it is failing.

## Run

```shell
cd k8s_pat
ansible-playbook -i inventory.ini playbook.yml
```

To make the play fail when any PAT case fails:

```shell
ansible-playbook -i inventory.ini playbook.yml -e pat_fail_play_on_failed_cases=true
```

## Extend Cases

Add items to `pat_cases` in `group_vars/pat.yml`. A case supports:

- `id`, `title`, `priority`, `mode`, `category`
- `scope`: `cluster`, `host`, `master`, `worker` or `all`
- `applicable`: boolean expression; false becomes `N/A`
- `na_reason`
- `command`
- `success_hint`
- `recommendation`

Keep production cases read-only by default. Synthetic and chaos cases should be
guarded by explicit switches and have cleanup steps.
