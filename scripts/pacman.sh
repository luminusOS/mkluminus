#!/usr/bin/env bash
#
# SPDX-License-Identifier: GPL-3.0-or-late

# Set up custom pacman.conf with custom cache and pacman hook directories.
make_pacman_conf() {
    local cache_dirs system_cache_dirs profile_cache_dirs
    pacman_conf="$(realpath -- "$pacman_conf")"
    system_cache_dirs="$(pacman-conf CacheDir| tr '\n' ' ')"
    profile_cache_dirs="$(pacman-conf --config "${pacman_conf}" CacheDir| tr '\n' ' ')"

    # Only use the profile's CacheDir, if it is not the default and not the same as the system cache dir.
    if [[ "${profile_cache_dirs}" != "/var/cache/pacman/pkg" ]] && \
        [[ "${system_cache_dirs}" != "${profile_cache_dirs}" ]]; then
        cache_dirs="${profile_cache_dirs}"
    else
        cache_dirs="${system_cache_dirs}"
    fi

    print_msg "Copying custom pacman.conf to work directory..."
    print_msg "Using pacman CacheDir: ${cache_dirs}"
    # take the profile pacman.conf and strip all settings that would break in chroot when using pacman -r
    # append CacheDir and HookDir to [options] section
    # HookDir is *always* set to the airootfs' override directory
    # see `man 8 pacman` for further info
    pacman-conf --config "${pacman_conf}" | \
        sed "/CacheDir/d;/DBPath/d;/HookDir/d;/LogFile/d;/RootDir/d;/\[options\]/a CacheDir = ${cache_dirs}
        /\[options\]/a HookDir = ${pacstrap_dir}/etc/pacman.d/hooks/" > "${work_dir}/pacman.conf"
}

# Install desired packages to the root file system
make_packages() {
    print_msg "Installing packages to '${pacstrap_dir}/'..."

    local packages_from_file=()
    local package_files
    package_files="$(ls "${defpath}"/packages/*.pkglist)"

    for pkg_file in ${package_files}; do
        mapfile -t packages_from_file < <(sed '/^[[:blank:]]*#.*/d;s/#.*//;/^[[:blank:]]*$/d' "${pkg_file}")
        packages+=("${packages_from_file[@]}")
    done

    # Unset TMPDIR to work around https://bugs.archlinux.org/task/70580
    if [[ "${silent_build}" = "yes" ]]; then
        env -u TMPDIR pacstrap -C "${work_dir}/pacman.conf" -c -G -M -- "${pacstrap_dir}" "${packages[@]}" &> /dev/null
    else
        env -u TMPDIR pacstrap -C "${work_dir}/pacman.conf" -c -G -M -- "${pacstrap_dir}" "${packages[@]}"
    fi

    print_msg "Done! Packages installed successfully."
}

make_pkglist() {
    print_msg "Creating a list of installed packages on live-enviroment..."
    install -d -m 0755 -- "${isofs_dir}/${install_dir}"
    pacman -Q --sysroot "${pacstrap_dir}" > "${isofs_dir}/${install_dir}/pkglist.${arch}.txt"
}