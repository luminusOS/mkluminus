#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-late

# Prepare working directory and copy custom root file system files.
make_custom_airootfs() {
    local passwd=()
    local filename permissions

    install -d -m 0755 -o 0 -g 0 -- "${pacstrap_dir}"

    if [[ -d "${defpath}/airootfs/" ]]; then
        print_msg "Copying custom airootfs files..."
        cp -af --no-preserve=ownership,mode -- "airootfs/." "${pacstrap_dir}"
        # Set ownership and mode for files and directories
        for filename in "${!file_permissions[@]}"; do
            IFS=':' read -ra permissions <<< "${file_permissions["${filename}"]}"
            # Prevent file path traversal outside of $pacstrap_dir
            if [[ "$(realpath -q -- "${pacstrap_dir}${filename}")" != "${pacstrap_dir}"* ]]; then
                print_msg "Failed to set permissions on '${pacstrap_dir}${filename}'. Outside of valid path." "error"
            # Warn if the file does not exist
            elif [[ ! -e "${pacstrap_dir}${filename}" ]]; then
                print_msg "Cannot change permissions of '${pacstrap_dir}${filename}'. The file or directory does not exist." "warn"
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

make_version() {
    local os_release

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
    os_release="$(realpath -- "${pacstrap_dir}/etc/os-release")"
    if [[ ! -e "${pacstrap_dir}/etc/os-release" && -e "${pacstrap_dir}/usr/lib/os-release" ]]; then
        os_release="$(realpath -- "${pacstrap_dir}/usr/lib/os-release")"
    fi
    if [[ "${os_release}" != "${pacstrap_dir}"* ]]; then
        print_msg "os-release file '${os_release}' is outside of valid path."
    else
        [[ ! -e "${os_release}" ]] || sed -i '/^IMAGE_ID=/d;/^IMAGE_VERSION=/d' "${os_release}"
        printf 'IMAGE_ID=%s\nIMAGE_VERSION=%s\n' "${iso_name}" "${iso_version}" >> "${os_release}"
    fi
}

# Customize installation.
make_customize_airootfs() {
    local passwd=()

    if [[ -e "${defpath}/airootfs/etc/passwd" ]]; then
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
                print_msg "Failed to set permissions on '${pacstrap_dir}${passwd[5]}'. Outside of valid path." "error"
            fi
        done < "${defpath}/airootfs/etc/passwd"
    fi

    for script in "${pacstrap_dir}/root/scripts"/*.sh; do
        if [[ -e "${script}" ]]; then
            print_msg "Running '${script}' in chroot..."
            chmod -f -- +x "${script}"
            eval -- env -u TMPDIR arch-chroot "${pacstrap_dir}" "/root/scripts/$(basename -- "$script")"
            rm -- "${script}"
        fi
    done
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

# Create a squashfs image containing the root file system and saves it on the ISO 9660 file system.
mkairootfs_squashfs() {
    local image_path="${isofs_dir}/${install_dir}/${arch}/airootfs.sfs"

    [[ -e "${pacstrap_dir}" ]] || print_msg "The path '${pacstrap_dir}' does not exist" "error"
    
    rm -f -- "${image_path}"
    install -d -m 0755 -- "${isofs_dir}/${install_dir}/${arch}"
    print_msg "Creating SquashFS image, this may take some time..."
    if [[ "${silent_build}" = "yes" ]]; then
        mksquashfs "${pacstrap_dir}" "${image_path}" -noappend -no-progress > /dev/null
    else
        mksquashfs "${pacstrap_dir}" "${image_path}" -noappend
    fi
    mkchecksum
}