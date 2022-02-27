#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-late

packages=()
defpath="$( cd "$( dirname "$0" )" && pwd )"
work_dir="${defpath}/work"
isofs_dir="${work_dir}/iso"
pacstrap_dir="${work_dir}/${arch}/airootfs"
out_dir="${defpath}/out"
pacman_conf="${defpath}/airootfs/etc/pacman.conf"