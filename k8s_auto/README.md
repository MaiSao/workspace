---
Title: Install Kubernetes guide
---
### 1. Prepare Repo

- Prepare Red Hat repo. Requires minimum AppStream and BaseOS in RHEL8+
- Prepare Kubernetes repo. Packages can be used in `install_tools` directories.

### 2. Prepare Container registry

- You can either use docker registry or Harbor registry.
- For production use, a HA harbor registry with minimum 3 replicas
  minimum is required.

### 3. Prepare ansible inventory

- A sample inventory is available at [`install_tools/inventory.ini`].
  The final inventory.ini need to be placed on repo root dir.
- Note that `k8s_ip` var is needed for each host entry
- Root privileage is required for all k8s nodes.

```ini
[masters]
1.255.0.7 priority=5 k8s_ip=1.255.0.7 ansible_ssh_user=root ansible_ssh_pass=myk8snow
```

### 4. Prepare host vars

- Change vars as desired in [`group_vars/all.yml`]. Follow the
  comment in the var file for instruction.

### 5. Deploy

- Once done preparation, you double-check the vars again.
- Simply run ansible-playbook on the `site.yml` playbook

```shell
$ ansible-playbook site.yml
```
