#! /bin/bash
set -xe

VMID="${VMID:-8202}"
STORAGE="${STORAGE:-vms}"
STORAGE_PATH="/mnt/zpool_nvme"
IMG="noble-server-cloudimg-amd64.img"
BASE_URL="https://cloud-images.ubuntu.com/noble/current"
EXPECTED_SHA=$(wget -qO- "$BASE_URL/SHA256SUMS" | awk '/'$IMG'/{print $1}')

download() {
    wget -q -P $STORAGE_PATH/template/iso "$BASE_URL/$IMG"
}

verify() {
    sha256sum "$STORAGE_PATH/template/iso/$IMG" | awk '{print $1}'
}

[ ! -f "$STORAGE_PATH/template/iso/$IMG" ] && download

ACTUAL_SHA=$(verify)
if [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ]; then
    rm -f "$STORAGE_PATH/template/iso/$IMG"
    download
    ACTUAL_SHA=$(verify)
    [ "$EXPECTED_SHA" != "$ACTUAL_SHA" ] && exit 1
fi

rm -f $STORAGE_PATH/template/iso/noble-server-cloudimg-amd64-resized.img
cp $STORAGE_PATH/template/iso/$IMG $STORAGE_PATH/template/iso/noble-server-cloudimg-amd64-resized.img
qemu-img resize $STORAGE_PATH/template/iso/noble-server-cloudimg-amd64-resized.img 8G

qm destroy $VMID || true
qm create $VMID --name "ubuntu-noble-template-nvidia-runtime" --ostype l26 \
    --memory 1024 --balloon 0 \
    --agent 1 \
    --bios ovmf --machine q35 \
    --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --socket 1 --cores 1 \
    --vga serial0 --serial0 socket \
    --net0 virtio,bridge=vmbr0
qm importdisk $VMID $STORAGE_PATH/template/iso/noble-server-cloudimg-amd64-resized.img $STORAGE
qm set $VMID --scsihw virtio-scsi-pci \
  --scsi0 $STORAGE:$VMID/vm-$VMID-disk-1.raw,discard=on
qm set $VMID --boot order=scsi0
qm set $VMID --scsi1 $STORAGE:cloudinit

mkdir -p $STORAGE_PATH/snippets
cat << EOF | tee $STORAGE_PATH/snippets/ubuntu-noble-nvidia.yaml
#cloud-config
runcmd:
    - curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    - curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    - apt-get update
    - apt-get install -y qemu-guest-agent nvidia-dkms-550-server nvidia-utils-550-server nvidia-container-runtime
    - systemctl enable ssh
    - reboot
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF

qm set $VMID --cicustom "vendor=$STORAGE:snippets/ubuntu-noble-nvidia.yaml"
qm set $VMID --tags ubuntu-template,noble,cloudinit,nvidia
qm set $VMID --ciuser $USER
qm set $VMID --sshkeys ~/.ssh/authorized_keys
qm set $VMID --ipconfig0 ip=dhcp,ip6=dhcp
qm template $VMID