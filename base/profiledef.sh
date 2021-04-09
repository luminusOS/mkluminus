#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="luminos-main"
iso_label="LUMINOS_$(date +%Y%m)"
iso_publisher="LuminOS Linux <https://www.archlinux.org>"
iso_application="LuminOS Linux main"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:0400"
)
