#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-later


base_path="$( cd "$( dirname "$0" )" && pwd )"
work_dir="${base_path}/work"
out_dir="${base_path}/out"
date_today="$( date +'%Y.%m.%d' )"
qemu_running=false

usage() {
    IFS='' read -r -d '' usagetext <<ENDUSAGETEXT || true
usage: build.sh [options]
  options:
     -h               This message
     -T               Use /tmp folder to work directory
     -r               Select a iso file name to run
     -r               Run latest builded iso
     -o               Change output iso directory

  profile_dir:        Directory of the archiso profile to build
ENDUSAGETEXT
    printf '%s' "${usagetext}"
    exit "${1}"
}

config_iso() {
    echo "[make] Checking dependencies..."
    if [[ ! -f "/usr/bin/mkarchiso" ]]; then
        echo "[make] ERROR: package 'archiso' not found."
        exit 1
    fi
}

build_iso() {
    # Check if work_dir exists and delete then
    # Necessary for rebuild the iso with base configurations if have any changes.
    # See https://wiki.archlinux.org/index.php/Archiso#Removal_of_work_directory
    if [ -d "${work_dir}" ]; then
        echo "[make] Deleting work folder..."
        echo "[make] Succesfully deleted $(rm -rfv "${work_dir}" | wc -l) files"
    fi
    exec scripts/mkarchiso.sh -v -w "${work_dir}" -o "${out_dir}" "${base_path}/base"
}

run_iso() {
    iso_file="$1"
    qemu_running=true
    sh scripts/qemu.sh -u -i "${iso_file}"
}

run_local_iso() {
    qemu_running=true
    sh scripts/qemu.sh -u -i "${out_dir}/luminus-main-${date_today}-x86_64.iso"
}

while getopts 'o:r:RTh?' arg; do
    case "${arg}" in
        T) 
            work_dir="/tmp/archiso-tmp"
            ;;
        R) 
            run_local_iso 
            ;;
        o) 
            out_dir="${OPTARG}"
            ;;
        r) 
            run_iso "${OPTARG}" 
            ;;
        h|?) usage 0 ;;
        *)
            echo "[make] Invalid argument '${arg}'" 0
            usage 1
            ;;
    esac
done

if [ "$qemu_running" = false ] ; then
    config_iso
    build_iso
fi

exit 0