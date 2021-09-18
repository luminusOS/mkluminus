#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-late
#
# forked and adapted from https://github.com/archlinux/archiso/blob/master/archiso/mkarchiso

set -e -u

# Control the environment
umask 0022
export LC_ALL="C"
export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-"$(date +%s)"}"

# ISO configuration variables
iso_name="luminus-main"
iso_label="LUMINUS_$(date +%Y%m)"
iso_publisher="Luminus OS Linux <https://luminusos.github.io/>"
iso_application="Luminus OS Linux main"
iso_version="$(date +%Y.%m.%d)"
arch="x86_64"
install_dir="lum"

# build.sh configuration variables
packages=()
base_path="$( cd "$( dirname "$0" )" && pwd )"
datetime="$(date '+%d/%m/%Y %H:%M:%S')"
work_dir="/tmp/luminus-build-iso" #"${base_path}/work"
isofs_dir="${work_dir}/iso"
pacstrap_dir="${work_dir}/${arch}/airootfs"
out_dir="${base_path}/out"
pacman_conf="${base_path}/airootfs/etc/pacman.conf"
declare -A file_permissions=(
    ["/etc/shadow"]="0:0:400"
    ["/etc/gshadow"]="0:0:0400"
    ["/root"]="0:0:750"
)
# adapted from GRUB_EARLY_INITRD_LINUX_STOCK in https://git.savannah.gnu.org/cgit/grub.git/tree/util/grub-mkconfig.in
readonly ucodes=('intel-uc.img' 'intel-ucode.img' 'amd-uc.img' 'amd-ucode.img' 'early_ucode.cpio' 'microcode.cpio')


# $1: message string
print_msg() {
    local message="${1}"
    printf '[%s]: %s\n' "${datetime}" "${message}" >&2
}

# Set up custom pacman.conf with custom cache and pacman hook directories.
make_pacman_conf() {
    local _cache_dirs _system_cache_dirs _profile_cache_dirs
    pacman_conf="$(realpath -- "$pacman_conf")"
    _system_cache_dirs="$(pacman-conf CacheDir| tr '\n' ' ')"
    _profile_cache_dirs="$(pacman-conf --config "${pacman_conf}" CacheDir| tr '\n' ' ')"

    # Only use the profile's CacheDir, if it is not the default and not the same as the system cache dir.
    if [[ "${_profile_cache_dirs}" != "/var/cache/pacman/pkg" ]] && \
        [[ "${_system_cache_dirs}" != "${_profile_cache_dirs}" ]]; then
        _cache_dirs="${_profile_cache_dirs}"
    else
        _cache_dirs="${_system_cache_dirs}"
    fi

    print_msg "Copying custom pacman.conf to work directory..."
    print_msg "Using pacman CacheDir: ${_cache_dirs}"
    # take the profile pacman.conf and strip all settings that would break in chroot when using pacman -r
    # append CacheDir and HookDir to [options] section
    # HookDir is *always* set to the airootfs' override directory
    # see `man 8 pacman` for further info
    pacman-conf --config "${pacman_conf}" | \
        sed "/CacheDir/d;/DBPath/d;/HookDir/d;/LogFile/d;/RootDir/d;/\[options\]/a CacheDir = ${_cache_dirs}
        /\[options\]/a HookDir = ${pacstrap_dir}/etc/pacman.d/hooks/" > "${work_dir}/pacman.conf"
}

# Prepare working directory and copy custom root file system files.
make_custom_airootfs() {
    local passwd=()
    local filename permissions

    install -d -m 0755 -o 0 -g 0 -- "${pacstrap_dir}"

    if [[ -d "${base_path}/airootfs/" ]]; then
        print_msg "Copying custom airootfs files..."
        cp -af --no-preserve=ownership,mode -- "airootfs/." "${pacstrap_dir}"
        # Set ownership and mode for files and directories
        for filename in "${!file_permissions[@]}"; do
            IFS=':' read -ra permissions <<< "${file_permissions["${filename}"]}"
            # Prevent file path traversal outside of $pacstrap_dir
            if [[ "$(realpath -q -- "${pacstrap_dir}${filename}")" != "${pacstrap_dir}"* ]]; then
                print_msg "Failed to set permissions on '${pacstrap_dir}${filename}'. Outside of valid path." 1
            # Warn if the file does not exist
            elif [[ ! -e "${pacstrap_dir}${filename}" ]]; then
                print_msg "Cannot change permissions of '${pacstrap_dir}${filename}'. The file or directory does not exist."
            else
                if [[ "${filename: -1}" == "/" ]]; then
                    chown -fhR -- "${permissions[0]}:${permissions[1]}" "${pacstrap_dir}${filename}"
                    chmod -fR -- "${permissions[2]}" "${pacstrap_dir}${filename}"
                else
                    chown -fh -- "${permissions[0]}:${permissions[1]}" "${pacstrap_dir}${filename}"
                    chmod -f -- "${permissions[2]}" "${pacstrap_dir}${filename}"
                fi
            fi
        done
        print_msg "Successfully maked custom airootfs!"
    fi
}

# Install desired packages to the root file system
make_packages() {
    print_msg "Installing packages to '${pacstrap_dir}/'..."

    local packages_from_file=()
    local package_files="$(ls ${base_path}/packages/*.pkglist)"

    for pkg_file in ${package_files}; do
        mapfile -t packages_from_file < <(sed '/^[[:blank:]]*#.*/d;s/#.*//;/^[[:blank:]]*$/d' "${pkg_file}")
        packages+=("${packages_from_file[@]}")
    done

    # Unset TMPDIR to work around https://bugs.archlinux.org/task/70580
    env -u TMPDIR pacstrap -C "${work_dir}/pacman.conf" -c -G -M -- "${pacstrap_dir}" "${packages[@]}"

    print_msg "Done! Packages installed successfully."
}

make_version() {
    local _os_release

    print_msg "Creating version files..."
    # Write version file to system installation dir
    rm -f -- "${pacstrap_dir}/version"
    printf '%s\n' "${iso_version}" > "${pacstrap_dir}/version"
    # Write version file to boot installation dir
    install -d -m 0755 -- "${isofs_dir}/${install_dir}"
    # Write version file to ISO 9660
    printf '%s\n' "${iso_version}" > "${isofs_dir}/${install_dir}/version"
    # Write grubenv with version information to ISO 9660
    printf '%.1024s' "$(printf '# GRUB Environment Block\nNAME=%s\nVERSION=%s\n%s' \
        "${iso_name}" "${iso_version}" "$(printf '%0.1s' "#"{1..1024})")" \
        > "${isofs_dir}/${install_dir}/grubenv"

    # Append IMAGE_ID & IMAGE_VERSION to os-release
    _os_release="$(realpath -- "${pacstrap_dir}/etc/os-release")"
    if [[ ! -e "${pacstrap_dir}/etc/os-release" && -e "${pacstrap_dir}/usr/lib/os-release" ]]; then
        _os_release="$(realpath -- "${pacstrap_dir}/usr/lib/os-release")"
    fi
    if [[ "${_os_release}" != "${pacstrap_dir}"* ]]; then
        print_msg "os-release file '${_os_release}' is outside of valid path."
    else
        [[ ! -e "${_os_release}" ]] || sed -i '/^IMAGE_ID=/d;/^IMAGE_VERSION=/d' "${_os_release}"
        printf 'IMAGE_ID=%s\nIMAGE_VERSION=%s\n' "${iso_name}" "${iso_version}" >> "${_os_release}"
    fi
}

# Customize installation.
make_customize_airootfs() {
    local passwd=()

    if [[ -e "${base_path}/airootfs/etc/passwd" ]]; then
        print_msg "Copying /etc/skel/* to user homes..."
        while IFS=':' read -a passwd -r; do
            # Only operate on UIDs in range 1000–59999
            (( passwd[2] >= 1000 && passwd[2] < 60000 )) || continue
            # Skip invalid home directories
            [[ "${passwd[5]}" == '/' ]] && continue
            [[ -z "${passwd[5]}" ]] && continue
            # Prevent path traversal outside of $pacstrap_dir
            if [[ "$(realpath -q -- "${pacstrap_dir}${passwd[5]}")" == "${pacstrap_dir}"* ]]; then
                if [[ ! -d "${pacstrap_dir}${passwd[5]}" ]]; then
                    install -d -m 0750 -o "${passwd[2]}" -g "${passwd[3]}" -- "${pacstrap_dir}${passwd[5]}"
                fi
                cp -dnRT --preserve=mode,timestamps,links -- "${pacstrap_dir}/etc/skel/." "${pacstrap_dir}${passwd[5]}"
                chmod -f 0750 -- "${pacstrap_dir}${passwd[5]}"
                chown -hR -- "${passwd[2]}:${passwd[3]}" "${pacstrap_dir}${passwd[5]}"
            else
                print_msg "Failed to set permissions on '${pacstrap_dir}${passwd[5]}'. Outside of valid path." 1
            fi
        done < "${base_path}/airootfs/etc/passwd"
    fi

    if [[ -e "${pacstrap_dir}/root/customize_airootfs.sh" ]]; then
        print_msg "Running customize_airootfs.sh in '${pacstrap_dir}' chroot..."
        print_msg "customize_airootfs.sh is deprecated! Support for it will be removed in a future archiso version."
        chmod -f -- +x "${pacstrap_dir}/root/customize_airootfs.sh"
        # Unset TMPDIR to work around https://bugs.archlinux.org/task/70580
        eval -- env -u TMPDIR arch-chroot "${pacstrap_dir}" "/root/customize_airootfs.sh"
        rm -- "${pacstrap_dir}/root/customize_airootfs.sh"
    fi
}

make_pkglist() {
    print_msg "Creating a list of installed packages on live-enviroment..."
    install -d -m 0755 -- "${isofs_dir}/${install_dir}"
    pacman -Q --sysroot "${pacstrap_dir}" > "${isofs_dir}/${install_dir}/pkglist.${arch}.txt"
}

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
    mkfs.fat -C -n LUM_ISO_EFI "${work_dir}/efiboot.img" "${imgsize}"

    # Create the default/fallback boot path in which a boot loaders will be placed later.
    mmd -i "${work_dir}/efiboot.img" ::/EFI ::/EFI/BOOT
}

make_uefi_boot() {
    local _file efiboot_imgsize
    local _available_ucodes=()
    print_msg "Setting up systemd-boot for UEFI booting..."

    for _file in "${ucodes[@]}"; do
        if [[ -e "${pacstrap_dir}/boot/${_file}" ]]; then
            _available_ucodes+=("${pacstrap_dir}/boot/${_file}")
        fi
    done
    # Calculate the required FAT image size in bytes
    efiboot_imgsize="$(du -bc \
        "${pacstrap_dir}/usr/share/refind/*.efi" \
        "${pacstrap_dir}/usr/share/refind/drivers_x64/*.efi" \
        "${pacstrap_dir}/usr/share/refind/icons/" \
        "${pacstrap_dir}/usr/share/refind/fonts/" \
        "${pacstrap_dir}/usr/share/edk2-shell/x64/Shell_Full.efi" \
        "${base_path}/efiboot/" \
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

    mmd -i "${work_dir}/efiboot.img" ::/EFI/BOOT/icons ::/EFI/BOOT/fonts ::/EFI/BOOT/theme
    mcopy -i "${work_dir}/efiboot.img" \
        "${pacstrap_dir}/usr/share/refind/icons" ::/EFI/BOOT/
    mcopy -i "${work_dir}/efiboot.img" \
        "${pacstrap_dir}/usr/share/refind/fonts" ::/EFI/BOOT/
    mcopy -i "${work_dir}/efiboot.img" \
        "${base_path}/efiboot/theme" ::/EFI/BOOT/
        
    mmd -i "${work_dir}/efiboot.img" ::/EFI/BOOT/theme/icons ::/EFI/BOOT/theme/fonts
    mcopy -i "${work_dir}/efiboot.img" \
        "${base_path}/efiboot/theme/icons" ::/EFI/BOOT/theme/
    mcopy -i "${work_dir}/efiboot.img" \
        "${base_path}/efiboot/theme/fonts" ::/EFI/BOOT/theme/

    for _conf in "${base_path}/efiboot/"*".conf"; do
        sed "s|%ARCHISO_LABEL%|${iso_label}|g;
             s|%INSTALL_DIR%|${install_dir}|g;
             s|%ARCH%|${arch}|g" \
            "${_conf}" | mcopy -i "${work_dir}/efiboot.img" - "::/EFI/BOOT/${_conf##*/}"
    done

    # shellx64.efi is picked up automatically when on /
    if [[ -e "${pacstrap_dir}/usr/share/edk2-shell/x64/Shell_Full.efi" ]]; then
        mcopy -i "${work_dir}/efiboot.img" \
            "${pacstrap_dir}/usr/share/edk2-shell/x64/Shell_Full.efi" ::/shellx64.efi
    fi

    print_msg "Done! rEFInd set up for UEFI booting successfully."

    # Additionally set up system-boot in ISO 9660. This allows creating a medium for the live environment by using
    # manual partitioning and simply copying the ISO 9660 file system contents.
    # This is not related to El Torito booting and no firmware uses these files.
    print_msg "Preparing an /EFI directory for the ISO 9660 file system..."
    install -d -m 0755 -- "${isofs_dir}/EFI/BOOT"

    # edk2-shell based UEFI shell
    # shellx64.efi is picked up automatically when on /
    if [[ -e "${pacstrap_dir}/usr/share/edk2-shell/x64/Shell_Full.efi" ]]; then
        install -m 0644 -- "${pacstrap_dir}/usr/share/edk2-shell/x64/Shell_Full.efi" "${isofs_dir}/shellx64.efi"
    fi

    # Copy kernel and initramfs to FAT image.
    # systemd-boot can only access files from the EFI system partition it was launched from.
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

# Cleanup airootfs
cleanup_pacstrap_dir() {
    print_msg "Cleaning up in pacstrap location..."

    # Delete all files in /boot
    [[ -d "${pacstrap_dir}/boot" ]] && find "${pacstrap_dir}/boot" -mindepth 1 -delete
    # Delete pacman database sync cache files (*.tar.gz)
    [[ -d "${pacstrap_dir}/var/lib/pacman" ]] && find "${pacstrap_dir}/var/lib/pacman" -maxdepth 1 -type f -delete
    # Delete pacman database sync cache
    [[ -d "${pacstrap_dir}/var/lib/pacman/sync" ]] && find "${pacstrap_dir}/var/lib/pacman/sync" -delete
    # Delete pacman package cache
    [[ -d "${pacstrap_dir}/var/cache/pacman/pkg" ]] && find "${pacstrap_dir}/var/cache/pacman/pkg" -type f -delete
    # Delete all log files, keeps empty dirs.
    [[ -d "${pacstrap_dir}/var/log" ]] && find "${pacstrap_dir}/var/log" -type f -delete
    # Delete all temporary files and dirs
    [[ -d "${pacstrap_dir}/var/tmp" ]] && find "${pacstrap_dir}/var/tmp" -mindepth 1 -delete
    # Delete package pacman related files.
    find "${work_dir}" \( -name '*.pacnew' -o -name '*.pacsave' -o -name '*.pacorig' \) -delete
    # Create an empty /etc/machine-id
    rm -f -- "${pacstrap_dir}/etc/machine-id"
    printf '' > "${pacstrap_dir}/etc/machine-id"
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

# Create a squashfs image containing the root file system and saves it on the ISO 9660 file system.
mkairootfs_squashfs() {
    local image_path="${isofs_dir}/${install_dir}/${arch}/airootfs.sfs"

    [[ -e "${pacstrap_dir}" ]] || _msg_error "The path '${pacstrap_dir}' does not exist" 1

    install -d -m 0755 -- "${isofs_dir}/${install_dir}/${arch}"
    print_msg "Creating SquashFS image, this may take some time..."
    mksquashfs "${pacstrap_dir}" "${image_path}" -noappend
    mkchecksum
}

# Build ISO
build_iso_image() {
    local xorrisofs_options=()
    local image_name="${iso_name}-${iso_version}-${arch}.iso"

    [[ -d "${out_dir}" ]] || install -d -- "${out_dir}"

    # The ISO will not contain a GPT partition table, so to be able to reference efiboot.img, place it as a
    # file inside the ISO 9660 file system
    install -d -m 0755 -- "${isofs_dir}/EFI/IMG"
    cp -a -- "${work_dir}/efiboot.img" "${isofs_dir}/EFI/IMG/efiboot.img"
    xorrisofs_options+=(
    '-partition_offset' '16'
    '-append_partition' '2' 'C12A7328-F81F-11D2-BA4B-00A0C93EC93B' "${work_dir}/efiboot.img"
    '-appended_part_as_gpt'
    '-eltorito-alt-boot' 
    '-e' 'EFI/IMG/efiboot.img'
    '-no-emul-boot')

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
    du -h -- "${out_dir}/${image_name}"
}

main() {
    # Check if work_dir exists and delete then
    # Necessary for rebuild the iso with base configurations if have any changes.
    # See https://wiki.archlinux.org/index.php/Archiso#Removal_of_work_directory
    if [ -d "${work_dir}" ]; then
        print_msg "Deleting work folder..."
        print_msg "Succesfully deleted $(rm -rfv "${work_dir}" | wc -l) files"
    fi
    
    install -d -- "${work_dir}"

    make_pacman_conf
    make_custom_airootfs
    make_packages
    make_version
    make_customize_airootfs
    make_pkglist
    make_uefi_boot
    cleanup_pacstrap_dir
    mkairootfs_squashfs
    build_iso_image
}

main
