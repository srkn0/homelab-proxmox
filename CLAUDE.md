# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a homelab infrastructure repository for setting up and managing a Proxmox VE hypervisor with ZFS storage, GPU passthrough, and VM templates.

## Repository Structure

- **ansible/** - Ansible playbooks for Proxmox and ZFS setup
- **debian-preseed/** - Automated Debian installer ISO builder using preseed
- **ubuntu-cloud-init/** - Scripts to create Ubuntu cloud-init VM templates on Proxmox

## Common Commands

### Ansible (run from `ansible/` directory)

```bash
# Install Ansible dependencies (required before running playbooks)
ansible-galaxy install -r requirements.yml -p ./roles

# Setup ZFS pools
ansible-playbook -i inventories/homelab.ini playbooks/setup_zfs.yml

# Install/configure Proxmox
ansible-playbook -i inventories/homelab.ini playbooks/install_proxmox.yml
```

### Debian Preseed ISO

```bash
# Prerequisites on Debian host
apt-get install -y --no-install-recommends xorriso isolinux pwgen

# Build preseeded ISO
./build /path/to/debian-netinst.iso /path/to/output-preseed.iso
```

### Ubuntu Cloud-Init Templates (run on Proxmox host)

```bash
# Create base Ubuntu Noble template (VM ID 8200)
VMID=8200 STORAGE=vms ./ubuntu-noble-cloudinit.sh

# Create Ubuntu Noble template with NVIDIA drivers (VM ID 8202)
VMID=8202 STORAGE=vms ./ubuntu-noble-cloudinit+nvidia+runtime.sh
```

## Architecture Notes

### Ansible Roles
- Uses `lae.proxmox` (v1.10.0) for Proxmox configuration including storage, users, ACLs, and GPU passthrough
- Uses `mrlesmithjr.zfs` (v0.1.2) for ZFS pool creation

### Storage Layout
The setup configures three ZFS pools:
- `zpool_k8s` - Striped mirror for Kubernetes workloads (4x Samsung SSDs)
- `zpool_nvme` - Single NVMe for VM images and ISOs
- `zpool_backup` - Single HDD for backups

### VM Templates
Cloud-init templates are created with:
- UEFI boot (OVMF)
- virtio-scsi storage controller
- QEMU guest agent
- SSH enabled with current user's authorized_keys
