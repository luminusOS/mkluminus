#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-late
#
# Author: Leandro Marques

while true
do
    sleep 4
    if [[ -e "/luminus/build.sh" ]]; then
        cd /luminus || exit
        mkdir -p /tmp/luminus /tmp/luminus/out /tmp/luminus/work
        sh build.sh -w /tmp/luminus/work -o /tmp/luminus/out -d
        exit
    fi
done