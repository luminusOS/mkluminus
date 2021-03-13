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
mkarchiso -v -w "${work_dir}" -o "${out_dir}" "${base_path}/main"
