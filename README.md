# My personal Homelab IaC

## Includes:
- Debian Preseed Iso Generation as base for the proxmox node(s)
- Setup and Configure ZFS via Ansible Role `mrlesmithjr.zfs`
- Setup and Configure Proxmox via Ansible Role `lae.proxmox`
- Create Proxmox VM Templates based on Ubuntu Cloud-init with a own small role at `roles/proxmox_cloudinit_template`
- Create Proxmox VMs through the previously described VM Templates with a own small role at `roles/proxmox_vm`
- Create and Upgrade Kubernetes Clusters via Kubespray
    - using the prebuilt kubespray docker image
    - declarative tasks via `Taskfile.yaml`

## Todo
- Put the debian preseed iso generation into a own small role inside of this repo 

## Homelab Specs
I just have one node at the moment and probably wont need more than that

- **CPU**: i5 10600k 
- **RAM**: 64GB DDR4 Crucial 2666Mhz 
- **Mainboard**: Gigabyte Z490 UD
- **GPU:**: RTX 3060 - not really using it at the moment, but plan to in future
- **Drives:**
    - 2x Samsung EVO 870 - 500GB - zfspool: k8s - vdev1 - mirror setup
    - 2x Samsung EVO 860 - 500GB - zfspool: k8s - vdev2 - mirror setup
        - The four Samsung SSDs are housed in a 5.25" drive bay, which supports four 2.5" SSDs with a SATA backplane and hot-swap capability.
    - 1x Crucial SSD - 256GB - system disk
    - 1x M.2 NVMe - 1TB - zfspool: vms
    - 1x Seagate 2TB HDD - zfspool: backups
- **PSU**: 500W Bequiet
- **Case**: Chieftec UK-02B-OP Cube Case

---

## common tasks

### install external role dependencies
**command**: `ansible-galaxy install -r requirements.yml -p ./roles`

### install / bootstrap zfs
**command**: `ansible-playbook -i inventory/proxmox/inventory.ini playbooks/setup_zfs.yml`

### install proxmox
**command**: `ansible-playbook -i inventory/proxmox/inventory.ini playbooks/install_proxmox.yml`

### setup cloudinit templates
**command**: `ansible-playbook -i inventory/proxmox/inventory.ini playbooks/setup_cloudinit_templates.yml`

### create proxmox vms
**command**: `ansible-playbook -i inventory/proxmox/inventory.ini playbooks/create_vms_8201.yml`
**command**: `ansible-playbook -i inventory/proxmox/inventory.ini playbooks/create_vms_8202.yml`

### bootstrap k8s cluster via kubespray
- `$CLUSTER` should be the folder name of the kubespray inventory residing at `$(pwd)/inventory/kubespray/$CLUSTER`

**command**: `task bootstrap-k8s-cluster -- $CLUSTER` 

### upgrade k8s cluster via kubespray

- `$CLUSTER` should be the folder name of the kubespray inventory residing at `$(pwd)/inventory/kubespray/$CLUSTER`
- make sure to change the `KUBESPRAY_VERSION` variable at `Taskfile.yaml`
- make sure to read docs for that specific version https://github.com/kubernetes-sigs/kubespray, `$KUBE_VERSION` needs to be supported by the used kubespray docker image version

**command**: `task upgrade-k8s-cluster -- $CLUSTER $KUBE_VERSION`

---

## node tweaks
- `apt install powertop -y && powertop --auto-tine`
- `echo powersave | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

---

## tailscale

- `https://community-scripts.github.io/ProxmoxVE/scripts?id=debian`
- `https://community-scripts.github.io/ProxmoxVE/scripts?id=add-tailscale-lxc`

```
echo 'net.ipv4.ip_forward = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' | sudo tee -a /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf
```
- `sudo tailscale set --advertise-routes=192.168.178.201/32` -  traefik metallb lb ip