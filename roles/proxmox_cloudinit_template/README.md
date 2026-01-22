# proxmox_cloudinit_template

Ansible role that builds **Proxmox VM templates** from upstream Ubuntu cloud
images. It downloads a cloud image (verifying its SHA-256 checksum), resizes it,
wraps it in a VM with sane defaults (UEFI/OVMF, `q35`, virtio-scsi, serial
console, QEMU guest agent), injects a cloud-init **vendor snippet**, and converts
the VM into a template.

The role is idempotent: a template whose VMID already exists is skipped.

## Requirements

- Runs **on the Proxmox host** (uses the `qm` CLI and `qemu-img`).
- Storage that supports snippets (the example homelab uses the `vms` storage on
  `/mnt/zpool_nvme`).

## Role variables

| Variable | Default | Description |
|---|---|---|
| `cloudinit_templates` | `[]` | List of templates to build (see below). |
| `cloudinit_storage` | `vms` | Proxmox storage for disks/snippets. |
| `cloudinit_storage_path` | `/mnt/zpool_nvme` | Filesystem path of that storage. |
| `cloudinit_user` | `{{ ansible_user }}` | Default cloud-init user. |
| `cloudinit_ssh_keys_file` | `~/.ssh/authorized_keys` | SSH keys injected via cloud-init. |
| `cloudinit_memory` / `cloudinit_cores` / `cloudinit_sockets` | `1024` / `1` / `1` | Default sizing. |
| `cloudinit_disk_size` | `8G` | Default resized disk size. |
| `cloudinit_bridge` | `vmbr0` | Network bridge. |

Each entry in `cloudinit_templates` supports: `vmid`, `name`, `image_url`,
`checksum_url`, `tags`, `vendor_data`, and may override any of the sizing/storage
defaults above per template.

## Example

```yaml
- name: Create Proxmox cloud-init VM templates
  hosts: all
  become: true
  roles:
    - role: proxmox_cloudinit_template
      vars:
        cloudinit_storage: "vms"
        cloudinit_storage_path: "/mnt/zpool_nvme"
        cloudinit_user: "root"
        cloudinit_templates:
          - vmid: 8200
            name: "ubuntu-noble-template"
            image_url: "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
            checksum_url: "https://cloud-images.ubuntu.com/noble/current/SHA256SUMS"
            tags: [ubuntu-template, noble, cloudinit]
            vendor_data: |
              #cloud-config
              runcmd:
                - apt-get update
                - apt-get install -y qemu-guest-agent
                - systemctl enable ssh
                - reboot
```

See [`playbooks/setup_cloudinit_templates.yml`](../../playbooks/setup_cloudinit_templates.yml)
for the full set of templates this homelab builds (generic, Kubernetes-ready, and
an NVIDIA/AI dev template).
