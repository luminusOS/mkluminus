#!/usr/bin/env bash
#
# Leandro Marques
# Email  : leandromqrs@hotmail.com
#
# build.sh
#
# The main script that runs the build
#

# Internal config
base_path="$( cd "$( dirname "$0" )" && pwd )"
work_dir="${base_path}/work"
out_dir="${base_path}/out"

# mkarchiso -v -w /path/to/work_dir -o /path/to/out_dir /path/to/profile/
# find . -type f -print0 | xargs -0 dos2unix
# chmod -R 755 work/
# ln -sfn /usr/lib/systemd/system/sddm.service display-manager.service

config_iso() {
    # Check if work_dir exists and delete then
    if [ -d "${work_dir}" ]; then
        echo "[makeiso] Deleting work folder..."
        sleep 2
        rm -rfv "${work_dir}"
    fi
    echo "[makeiso] Creating home folder and giving correct permissions..."
    #mkdir -p "${work_dir}/x86_64/airootfs/home/live"
    #chown 1000 "${work_dir}/x86_64/airootfs/home/live"
}

build_iso() {
    exec mkarchiso -v -w "${work_dir}" -o "${out_dir}" "${base_path}/basic"
}

run_iso() {
    run_archiso -i "${base_path}/out/luminos-baseline-2021.04.03-x86_64.iso"
}

config_iso
build_iso
run_iso

exit 0