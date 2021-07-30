#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-later


base_path="$( cd "$( dirname "$0" )" && pwd )"
work_dir="${base_path}/work"
out_dir="${base_path}/out"
date_today="$( date +'%Y.%m.%d' )"
qemu_running=false

# mkarchiso -v -w /path/to/work_dir -o /path/to/out_dir /path/to/profile/
# find . -type f -print0 | xargs -0 dos2unix
# chmod -R 755 work/
# ln -sfn /usr/lib/systemd/system/sddm.service display-manager.service

_usage() {
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

_config_iso() {
    echo "[make] Checking dependencies..."
    if [[ ! -f "/usr/bin/mkarchiso" ]]; then
        echo "[make] ERROR: package 'archiso' not found."
        exit 1
    fi
    if [[ -v override_work_dir ]]; then
        work_dir="$override_work_dir"
    fi
    if [[ -v override_out_dir ]]; then
        out_dir="$override_out_dir"
    fi
}

_build_iso() {
    # Check if work_dir exists and delete then
    # Necessary for rebuild the iso with base configurations if have any changes.
    # See https://wiki.archlinux.org/index.php/Archiso#Removal_of_work_directory
    if [ -d "${work_dir}" ]; then
        echo "[make] Deleting work folder..."
        echo "[make] Succesfully deleted $(rm -rfv "${work_dir}" | wc -l) files"
    fi
    exec mkarchiso -v -w "${work_dir}" -o "${out_dir}" "${base_path}/base"
}

_run_iso() {
    iso_file="$1"
    qemu_running=true
    sh "scripts/qemu.sh" -u -i "${iso_file}"
}

_run_local_iso() {
    qemu_running=true
    sh "scripts/qemu.sh" -u -i "${out_dir}/luminos-main-${date_today}-x86_64.iso"
}

while getopts 'o:r:RTh?' arg; do
    case "${arg}" in
        T) override_work_dir="/tmp/archiso-tmp" ;;
        R) _run_local_iso ;;
        o) override_out_dir="${OPTARG}" ;;
        r) _run_iso "${OPTARG}" ;;
        h|?) _usage 0 ;;
        *)
            echo "[make] Invalid argument '${arg}'" 0
            _usage 1
            ;;
    esac
done

if [ "$qemu_running" = false ] ; then
    _config_iso
    _build_iso
fi

exit 0