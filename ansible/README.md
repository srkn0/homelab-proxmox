# install dependencies
`ansible-galaxy install -r requirements.yml -p ./roles`

# install / bootstrap zfs
`ansible-playbook -i inventories/homelab.ini playbooks/setup_zfs.yml`

# install proxmox
`ansible-playbook -i inventories/homelab.ini playbooks/install_proxmox.yml`

# ansible-playbook -i inventories/homelab.ini playbooks/setup_cloudinit_templates.yml