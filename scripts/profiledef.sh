#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-late

iso_name="luminus-$(git branch --show-current)"
iso_label="LUMINUS_$(date +%Y%m)"
iso_publisher="Luminus OS <https://luminusos.github.io/>"
iso_application="Luminus OS"
iso_version="$(date +%Y.%m.%d)"
install_dir="luminus"
arch="x86_64"