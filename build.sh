#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-late
#
# Forked and adapted from https://github.com/archlinux/archiso/blob/master/archiso/mkarchiso

set -e -u

# Control the environment
umask 0022
export LC_ALL="C"
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-"$(date +%s)"}"

source "scripts/profiledef.sh"
source "scripts/global.sh"
source "scripts/pacman.sh"
source "scripts/airootfs.sh"
source "scripts/bootmode.sh"
source "scripts/image.sh"

declare -A file_permissions=(
    ["/etc/shadow"]="0:0:400"
    ["/etc/gshadow"]="0:0:0400"
    ["/root"]="0:0:750"
)
# adapted from GRUB_EARLY_INITRD_LINUX_STOCK in https://git.savannah.gnu.org/cgit/grub.git/tree/util/grub-mkconfig.in
readonly ucodes=('intel-uc.img' 'intel-ucode.img' 'amd-uc.img' 'amd-ucode.img' 'early_ucode.cpio' 'microcode.cpio')
readonly dependencies=('pacman-conf' 'pacstrap' 'pacman' 'mkfs.fat' 'mkfs.ext4' 'mksquashfs' 'xorriso')

usage() {
    IFS='' read -r -d '' usagetext <<ENDUSAGETEXT || true
usage: build.sh [options]
  options:
     -h                 This message
     -d                 Delete work directory if exists
     -s                 Silent build
     -o [directory]     Change output iso directory
     -w [directory]     Change work directory
Example:
    Build an Luminus ISO image:
    $ build.sh -o "~/luminus-iso" -w "~/luminus-work" -d -s
ENDUSAGETEXT
    printf '%s' "${usagetext}"
    exit "${1}"
}

# $1: message string
print_msg() {
    local message="${1}"
    local type="${2:-}"
    local datetime
    datetime="$(date '+%d/%m/%Y %H:%M:%S')"
    case "${type}" in
    warn)
        printf '\e[1;33m%s\e[0m\n' "${datetime} [WARN] ${message}"
        ;;
    error)
        printf '\e[1;31m%s\e[0m\n' "${datetime} [ERROR] ${message}"
        exit 1
        ;;
    *)
        printf '\e[1;37m%s\e[0m\n' "${datetime} [INFO] ${message}"
        ;;
    esac
}

# Verify necessary dependencies are installed
verify_dependencies() {
    local missing_dependencies=()
    for dependency in "${dependencies[@]}"; do
        if ! command -v "${dependency}" >/dev/null 2>&1; then
            missing_dependencies+=("${dependency}")
        fi
    done
    if [[ "${#missing_dependencies[@]}" -gt 0 ]]; then
        print_msg "Missing dependencies: ${missing_dependencies[*]}" "error"
        exit 1
    fi
}

build() {
    # Check if work_dir exists and delete then
    # Necessary for rebuild the iso with base configurations if have any changes.
    # See https://wiki.archlinux.org/index.php/Archiso#Removal_of_work_directory
    if [[ -d "${work_dir}" && ${delete_work_dir} == "yes" ]]; then
        print_msg "Deleting work folder..."
        print_msg "Succesfully deleted $(rm -rfv "${work_dir}" | wc -l) files"
    fi
    
    install -d -- "${work_dir}"

    verify_dependencies
    make_pacman_conf
    make_custom_airootfs
    make_packages
    make_version
    make_customize_airootfs
    make_pkglist
    make_uefi_bootmode
    cleanup_pacstrap_dir
    mkairootfs_squashfs
    build_iso_image
}

delete_work_dir="no"
silent_build="no"

while getopts 'o:w:sdh?' arg; do
    case "${arg}" in
        d)
            delete_work_dir="yes"
            ;;
        o) 
            out_dir="${OPTARG}"
            ;;
        s)
            silent_build="yes"
            ;;
        w)
            work_dir="${OPTARG}"
            isofs_dir="${OPTARG}/iso"
            pacstrap_dir="${OPTARG}/${arch}/airootfs"
            ;;
        h|\?) usage 0 ;;
        *)
            print_msg "Invalid argument '${arg}'" "error"
            usage 1
            ;;
    esac
done

build

exit 0
