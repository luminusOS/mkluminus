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
        sh build.sh -d
        exit
    fi
done