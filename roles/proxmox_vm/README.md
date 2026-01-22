# proxmox_vm

Ansible role that provisions **Proxmox VMs by full-cloning a cloud-init template**
(see the [`proxmox_cloudinit_template`](../proxmox_cloudinit_template) role). For
each VM it clones the template, sets memory/cores, resizes the disk, and applies
cloud-init network + user + SSH-key configuration, then optionally starts it.

The role is idempotent: a VM whose VMID already exists is skipped.

## Requirements

- Runs **on the Proxmox host** (uses the `qm` CLI).
- A source template must already exist (built by `proxmox_cloudinit_template`).

## Role variables

| Variable | Default | Description |
|---|---|---|
| `proxmox_vms` | `[]` | List of VMs to create (see below). |
| `vm_template_vmid` | `8200` | Default template VMID to clone. |
| `vm_memory` / `vm_cores` | `2048` / `2` | Default sizing. |
| `vm_disk_size` | `20G` | Default disk size after resize. |
| `vm_bridge` | `vmbr0` | Network bridge. |
| `vm_ip` | `dhcp` | `dhcp` or a static address (with `vm_cidr`/`vm_gateway`). |
| `vm_cidr` / `vm_gateway` / `vm_nameserver` | `24` / `""` / `""` | Static-network settings. |
| `vm_user` | `{{ ansible_user }}` | cloud-init user. |
| `vm_ssh_keys_file` | `~/.ssh/authorized_keys` | SSH keys injected via cloud-init. |
| `vm_start_after_create` | `true` | Start the VM once created. |

Each entry in `proxmox_vms` supports: `vmid`, `name`, `tags`, and may override any
default above per VM (`template_vmid`, `memory`, `cores`, `disk_size`, `ip`,
`cidr`, `gateway`, `nameserver`, etc.).

## Example

```yaml
- name: Create Kubernetes VMs from the cloud-init template
  hosts: all
  become: true
  roles:
    - role: proxmox_vm
      vars:
        vm_template_vmid: 8201        # kubernetes-ready template
        vm_gateway: "192.168.178.1"
        vm_nameserver: "1.1.1.1"
        vm_user: "root"
        proxmox_vms:
          - vmid: 9001
            name: "k8s-home-01"
            memory: 16384
            cores: 6
            disk_size: "50G"
            ip: "192.168.178.215"
            cidr: 24
            tags: [kubernetes, master]
```

See [`playbooks/create_k8s_vms.yml`](../../playbooks/create_k8s_vms.yml) and
[`playbooks/create_dev_vm.yml`](../../playbooks/create_dev_vm.yml) for the VMs this
homelab provisions.
