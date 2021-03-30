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

build_iso() {
    # Check if work_dir exists and delete then
    if [ -d "${work_dir}" ]; then
        echo "Deleting work folder..."
        sleep 2
        rm -rfv "${work_dir}"
    fi
    mkarchiso -v -w "${work_dir}" -o "${out_dir}" "${base_path}/main"
}

#build_iso
build_iso
#echo "Executing chmod..."
#chmod -R 755 "${work_dir}"
#find "${work_dir}" -type d -exec chmod 755 {} \;
exit 0