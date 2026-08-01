# debian_preseed_iso

Ansible role that remasters a stock Debian **netinst** ISO into a *preseeded*
installer. Preseeding answers the installer's routine questions up front so a
new Proxmox node comes up with a known-good, repeatable base system.

What the generated installer does:

- Creates a **root-only** system (no extra user) with an SSH `authorized_keys` file.
- Static installer networking, German locale/keymap, and a Debian mirror by default
  (all configurable, see variables below).
- Installs standard utilities and an SSH server.
- Replaces `systemd-timesyncd` with **chrony** for better Proxmox compatibility.
- Configures `/etc/network/interfaces` with a `vmbr0` bridge ready for Proxmox.

Disk partitioning is intentionally **left interactive**: it is the riskiest part
of an unattended install, so the operator confirms the target disk by hand.

## How it works

The actual ISO surgery (unpacking the initrd, injecting `preseed.cfg` + the
postinstall payload via `cpio`, and re-mastering with `xorriso`) is done by the
`files/build` shell script. This role's job is to render the configuration from
variables, assemble a build workspace, and invoke that script, so the result is
parameterized and repeatable instead of a pile of hand-edited files.

## Requirements

- A **Debian** build host (the role installs `xorriso`, `isolinux`, `pwgen` via apt).
- A source Debian netinst ISO, download from <https://www.debian.org/distrib/netinst>.

## Role variables

| Variable | Default | Description |
|---|---|---|
| `preseed_input_iso` | `""` (**required**) | Path to the source Debian netinst ISO. |
| `preseed_output_iso` | `{{ playbook_dir }}/preseed-debian-amd64-netinst.iso` | Where the generated ISO is written. |
| `preseed_locale` | `de_DE.UTF-8` | Installer locale. |
| `preseed_keymap` | `de` | Keyboard layout. |
| `preseed_timezone` | `UTC` | System timezone. |
| `preseed_mirror_country` / `preseed_mirror_hostname` | `DE` / `deb.debian.org` | Debian mirror. |
| `preseed_ntp_server` | `de.pool.ntp.org` | NTP pool (install + chrony). |
| `preseed_install_interface` | `enp4s0` | Interface configured during install. |
| `preseed_nameservers` | `1.1.1.1 1.0.0.1` | Installer DNS servers. |
| `preseed_root_password_hash` | `!` | Root password hash. The default locks password login; set a hash from `mkpasswd` if you need password auth. |
| `preseed_root_password` | `""` | Optional plaintext root password for short-lived lab installs only. Ignored when `preseed_root_password_hash` is set. |
| `preseed_authorized_keys` | (a sample ed25519 key) | Public key(s) added to `/root/.ssh/authorized_keys`. |
| `preseed_bridge_port` | `ens33` | Physical NIC enslaved to `vmbr0`. |
| `preseed_bridge_address` | `192.168.178.90/24` | Static address for `vmbr0`. |
| `preseed_bridge_gateway` | `192.168.178.1` | Default gateway. |
| `preseed_bridge_netmask` | `255.255.255.0` | Netmask for `vmbr0`. |
| `preseed_bridge_nameservers` | `1.1.1.1 1.0.0.1` | DNS servers for the running host. |
| `preseed_build_packages` | `[xorriso, isolinux, pwgen]` | Build-host packages. |

> The default network, host, and SSH-key values are this homelab's reference
> values. Override them with `-e` or in your inventory for your own environment.

## Usage

```bash
ansible-playbook playbooks/build_preseed_iso.yml \
  -e input_iso=/path/to/debian-13.x.x-amd64-netinst.iso \
  -e output_iso=/path/to/preseed-debian-13.x.x-amd64-netinst.iso
```

Then write the ISO to a USB stick and boot the target machine:

```bash
# Linux: replace /dev/sdX with your USB device (lsblk)
sudo dd bs=4M if=preseed-debian-amd64-netinst.iso of=/dev/sdX conv=fdatasync
```

A preseeded ISO is only useful for bare-metal / VM installs, not cloud instances.

## Credits

The ISO-remastering technique (initrd repacking via `cpio` + `xorriso`) is adapted
from Paul Lockaby's preseed work: <https://github.com/paullockaby>. See also the
Debian preseed documentation: <https://wiki.debian.org/DebianInstaller/Preseed>.
