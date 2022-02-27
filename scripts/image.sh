#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-late

# Build ISO
build_iso_image() {
    local xorrisofs_options=()
    local image_name="${iso_name}-${iso_version}-${arch}.iso"

    [[ -d "${out_dir}" ]] || install -d -- "${out_dir}"
    [[ "${silent_build}" == "yes" ]] && xorrisofs_options+=('-quiet')

    # The ISO will not contain a GPT partition table, so to be able to reference efiboot.img, place it as a
    # file inside the ISO 9660 file system
    install -d -m 0755 -- "${isofs_dir}/EFI"
    cp -a -- "${work_dir}/efiboot.img" "${isofs_dir}/EFI/efiboot.img"
    xorrisofs_options+=(
    '-partition_offset' '16'
    '-append_partition' '2' 'C12A7328-F81F-11D2-BA4B-00A0C93EC93B' "${work_dir}/efiboot.img"
    '-appended_part_as_gpt'
    '-eltorito-alt-boot'
    '-isohybrid-gpt-basdat'
    '-no-emul-boot'
    '-e' '--interval:appended_partition_2:all::'
    '-eltorito-boot' 'EFI/efiboot.img'
    '-eltorito-platform' 'efi'
    '-eltorito-catalog' 'EFI/boot.cat')

    print_msg "Creating ISO image..."
    xorriso -as mkisofs \
            -iso-level 3 \
            -full-iso9660-filenames \
            -joliet \
            -joliet-long \
            -rational-rock \
            -volid "${iso_label}" \
            -appid "${iso_application}" \
            -publisher "${iso_publisher}" \
            -preparer "prepared by Luminus OS Community" \
            "${xorrisofs_options[@]}" \
            -output "${out_dir}/${image_name}" \
            "${isofs_dir}/"
    print_msg "ISO image created in ""${out_dir}"/"${image_name}"""
    du -h -- "${out_dir}/${image_name}"
}