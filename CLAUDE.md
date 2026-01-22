# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ansible-based infrastructure-as-code for deploying Proxmox VE virtualization on bare metal homelab systems. The project handles the full stack from OS installation to cloud-init VM templates.

## Commands

### Install Ansible Role Dependencies
```bash
cd ansible
ansible-galaxy install -r requirements.yml -p ./roles
```

### Run Playbooks (execute in order)
```bash
cd ansible
ansible-playbook -i inventories/homelab.ini playbooks/setup_zfs.yml
ansible-playbook -i inventories/homelab.ini playbooks/install_proxmox.yml
ansible-playbook -i inventories/homelab.ini playbooks/setup_cloudinit_templates.yml
```

### Build Custom Debian Preseed ISO
```bash
cd debian-preseed
./build /path/to/debian-13.x.x-amd64-netinst.iso /path/to/output.iso
# Requires: xorriso, isolinux, pwgen
```

## Architecture

```
ansible/
├── ansible.cfg                    # Sets roles_path to ./roles
├── requirements.yml               # External roles: lae.proxmox, mrlesmithjr.zfs
├── inventories/homelab.ini        # Single host: 192.168.178.90 (root)
├── playbooks/
│   ├── setup_zfs.yml              # ZFS pool creation (3 pools: k8s, nvme, backup)
│   ├── install_proxmox.yml        # Proxmox installation with GPU passthrough
│   └── setup_cloudinit_templates.yml  # Ubuntu cloud-init template creation
└── roles/
    └── proxmox_cloudinit_template/    # Custom role for VM templates

debian-preseed/
├── build                          # ISO repack script
├── preseed.cfg                    # Automated Debian installer config
└── postinstall.d/                 # Post-install scripts (SSH keys, configs)
```

## Key Conventions

- **Variable prefixes**: `pve_` for lae.proxmox role, `cloudinit_` for custom role
- **Pool naming**: `zpool_*` (k8s, nvme, backup)
- **VM template IDs**: 8200+ range to avoid conflicts with regular VMs
- **Device identifiers**: Use persistent naming (ata-*, nvme-*) in ZFS configs
- **Tags**: kebab-case (e.g., ubuntu-template, cloudinit, nvidia)

## External Role Documentation

- lae.proxmox: https://github.com/lae/ansible-role-proxmox
- mrlesmithjr.zfs: https://github.com/mrlesmithjr/ansible-zfs
