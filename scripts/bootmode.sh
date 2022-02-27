#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-late

# Create a FAT image (efiboot.img) which will serve as the EFI system partition
# $1: image size in bytes
make_efibootimg() {
    local imgsize="0"

    # Convert from bytes to KiB and round up to the next full MiB with an additional MiB for reserved sectors.
    imgsize="$(awk 'function ceil(x){return int(x)+(x>int(x))}
            function byte_to_kib(x){return x/1024}
            function mib_to_kib(x){return x*1024}
            END {print mib_to_kib(ceil((byte_to_kib($1)+1024)/1024))}' <<< "${1}"
    )"
    # The FAT image must be created with mkfs.fat not mformat, as some systems have issues with mformat made images:
    # https://lists.gnu.org/archive/html/grub-devel/2019-04/msg00099.html
    [[ -e "${work_dir}/efiboot.img" ]] && rm -f -- "${work_dir}/efiboot.img"
    print_msg "Creating FAT image of size: ${imgsize} KiB..."
    if [[ "${silent_build}" == "yes" ]]; then
        mkfs.fat -C -n LUM_ISO_EFI "${work_dir}/efiboot.img" "${imgsize}" &> /dev/null
    else
        mkfs.fat -C -v -n LUM_ISO_EFI "${work_dir}/efiboot.img" "${imgsize}" #2>&1 | tee -a "${log_file}"
    fi

    # Create the default/fallback boot path in which a boot loaders will be placed later.
    mmd -i "${work_dir}/efiboot.img" ::/EFI ::/EFI/BOOT
}

make_uefi_bootmode() {
    local _file efiboot_imgsize
    local _available_ucodes=()
    print_msg "Setting up rEFInd for UEFI booting..."

    for _file in "${ucodes[@]}"; do
        if [[ -e "${pacstrap_dir}/boot/${_file}" ]]; then
            _available_ucodes+=("${pacstrap_dir}/boot/${_file}")
        fi
    done
    # Calculate the required FAT image size in bytes
    efiboot_imgsize="$(du -bc \
        "${pacstrap_dir}/usr/share/refind"/*.efi"" \
        "${pacstrap_dir}/usr/share/refind/drivers_x64"/*.efi"" \
        "${pacstrap_dir}/usr/share/refind/icons/" \
        "${pacstrap_dir}/usr/share/refind/fonts/" \
        "${pacstrap_dir}/usr/share/refind/themes/" \
        "${pacstrap_dir}/usr/share/edk2-shell/x64/Shell_Full.efi" \
        "${defpath}/efiboot"/* \
        "${pacstrap_dir}/boot/vmlinuz-"* \
        "${pacstrap_dir}/boot/initramfs-"*".img" \
        "${_available_ucodes[@]}" \
        2>/dev/null | awk 'END { print $1 }')"
    # Create a FAT image for the EFI system partition
    make_efibootimg "$efiboot_imgsize"

    # Copy systemd-boot EFI binary to the default/fallback boot path
    mcopy -i "${work_dir}/efiboot.img" \
        "${pacstrap_dir}/usr/share/refind/refind_x64.efi" ::/EFI/BOOT/BOOTx64.EFI

    mmd -i "${work_dir}/efiboot.img" ::/EFI/BOOT/drivers_x64
    mcopy -i "${work_dir}/efiboot.img" \
        "${pacstrap_dir}/usr/share/refind/drivers_x64/iso9660_x64.efi" ::/EFI/BOOT/drivers_x64/
    mcopy -i "${work_dir}/efiboot.img" \
        "${pacstrap_dir}/usr/share/refind/drivers_x64/ext4_x64.efi" ::/EFI/BOOT/drivers_x64/

    mmd -i "${work_dir}/efiboot.img" ::/EFI/BOOT/icons ::/EFI/BOOT/fonts ::/EFI/BOOT/themes
    mcopy -i "${work_dir}/efiboot.img" \
        "${pacstrap_dir}/usr/share/refind/icons" ::/EFI/BOOT/
    mcopy -i "${work_dir}/efiboot.img" \
        "${pacstrap_dir}/usr/share/refind/fonts" ::/EFI/BOOT/
    
    mmd -i "${work_dir}/efiboot.img" ::/EFI/BOOT/themes/orchiis ::/EFI/BOOT/themes/orchiis/icons ::/EFI/BOOT/themes/orchiis/fonts
    mcopy -i "${work_dir}/efiboot.img" \
        "${pacstrap_dir}/usr/share/refind/themes/orchiis" ::/EFI/BOOT/themes/
    mcopy -i "${work_dir}/efiboot.img" \
        "${pacstrap_dir}/usr/share/refind/themes/orchiis/fonts" ::/EFI/BOOT/themes/orchiis/
    mcopy -i "${work_dir}/efiboot.img" \
        "${pacstrap_dir}/usr/share/refind/themes/orchiis/icons" ::/EFI/BOOT/themes/orchiis/

    for _conf in "${defpath}/efiboot/"*".conf"; do
        sed "s|%ARCHISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g;
             s|%ARCH%|${arch}|g" \
            "${_conf}" | mcopy -i "${work_dir}/efiboot.img" - "::/EFI/BOOT/${_conf##*/}"
    done
    mcopy -i "${work_dir}/efiboot.img" \
        "${defpath}/efiboot/startup.nsh" ::/

    # shellx64.efi is picked up automatically when on /
    if [[ -e "${pacstrap_dir}/usr/share/edk2-shell/x64/Shell_Full.efi" ]]; then
        mcopy -i "${work_dir}/efiboot.img" \
            "${pacstrap_dir}/usr/share/edk2-shell/x64/Shell_Full.efi" ::/shellx64.efi
    fi

    print_msg "Done! rEFInd set up for UEFI booting successfully."

    # Make kernel and initramfs available in the root system partition.
    install -d -m 0755 -- "${isofs_dir}/${install_dir}/boot/${arch}"
    install -m 0644 -- "${pacstrap_dir}/boot/initramfs-"*".img" "${isofs_dir}/${install_dir}/boot/${arch}/"
    install -m 0644 -- "${pacstrap_dir}/boot/vmlinuz-"* "${isofs_dir}/${install_dir}/boot/${arch}/"

    for ucode_image in "${ucodes[@]}"; do
        if [[ -e "${pacstrap_dir}/boot/${ucode_image}" ]]; then
            install -m 0644 -- "${pacstrap_dir}/boot/${ucode_image}" "${isofs_dir}/${install_dir}/boot/"
            if [[ -e "${pacstrap_dir}/usr/share/licenses/${ucode_image%.*}/" ]]; then
                install -d -m 0755 -- "${isofs_dir}/${install_dir}/boot/licenses/${ucode_image%.*}/"
                install -m 0644 -- "${pacstrap_dir}/usr/share/licenses/${ucode_image%.*}/"* \
                    "${isofs_dir}/${install_dir}/boot/licenses/${ucode_image%.*}/"
            fi
        fi
    done

    # Additionally set up system-boot in ISO 9660. This allows creating a medium for the live environment by using
    # manual partitioning and simply copying the ISO 9660 file system contents.
    # This is not related to El Torito booting and no firmware uses these files.
    print_msg "Preparing an /EFI directory for the ISO 9660 file system..."
    install -d -m 0755 -- "${isofs_dir}/EFI"

    # edk2-shell based UEFI shell
    # shellx64.efi is picked up automatically when on /
    if [[ -e "${pacstrap_dir}/usr/share/edk2-shell/x64/Shell_Full.efi" ]]; then
        install -m 0644 -- "${pacstrap_dir}/usr/share/edk2-shell/x64/Shell_Full.efi" "${isofs_dir}/shellx64.efi"
    fi

    # Copy kernel and initramfs to FAT image.
    # rEFInd can only access files from the EFI system partition it was launched from.
    local ucode_image all_ucode_images=()
    print_msg "Preparing kernel and initramfs for the FAT file system..."
    mmd -i "${work_dir}/efiboot.img" \
        "::/${install_dir}" "::/${install_dir}/boot" "::/${install_dir}/boot/${arch}"
    mcopy -i "${work_dir}/efiboot.img" "${pacstrap_dir}/boot/vmlinuz-"* \
        "${pacstrap_dir}/boot/initramfs-"*".img" "::/${install_dir}/boot/${arch}/"
    for ucode_image in "${ucodes[@]}"; do
        if [[ -e "${pacstrap_dir}/boot/${ucode_image}" ]]; then
            all_ucode_images+=("${pacstrap_dir}/boot/${ucode_image}")
        fi
    done
    if (( ${#all_ucode_images[@]} )); then
        mcopy -i "${work_dir}/efiboot.img" "${all_ucode_images[@]}" "::/${install_dir}/boot/"
    fi
}

# Create checksum file for the rootfs image.
mkchecksum() {
    print_msg "Creating checksum file for self-test..."
    cd -- "${isofs_dir}/${install_dir}/${arch}"
    if [[ -e "${isofs_dir}/${install_dir}/${arch}/airootfs.sfs" ]]; then
        sha512sum airootfs.sfs > airootfs.sha512
    elif [[ -e "${isofs_dir}/${install_dir}/${arch}/airootfs.erofs" ]]; then
        sha512sum airootfs.erofs > airootfs.sha512
    fi
    cd -- "${OLDPWD}"
}