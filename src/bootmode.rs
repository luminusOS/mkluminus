use std::env;
use std::fs::{self, File};
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::{self, Command, exit};


fn print_msg(message: &str, level: &str) {
    println!("{}: {}", level, message);
}

fn make_efibootimg(image_size: u64, work_dir: &str, silent_build: &str) {
    let image_size_kib = ((image_size / 1024) + 1024) / 1024;
    let image_size_bytes = image_size.to_string();

    if Path::new(&format!("{}/efiboot.img", work_dir)).exists() {
        if let Err(_) = fs::remove_file(format!("{}/efiboot.img", work_dir)) {
            print_msg("Failed to delete existing efiboot.img", "error");
            exit(1);
        }
    }

    print_msg(&format!("Creating FAT image of size: {} KiB...", image_size_kib), "info");

    let mut mkfs_fat_cmd = Command::new("mkfs.fat");
    mkfs_fat_cmd.arg("-C");
    mkfs_fat_cmd.arg("-n");
    mkfs_fat_cmd.arg("LUM_ISO_EFI");
    mkfs_fat_cmd.arg(&format!("{}/efiboot.img", work_dir));
    mkfs_fat_cmd.arg(image_size_bytes);

    if silent_build == "yes" {
        mkfs_fat_cmd.stdout(process::Stdio::null()).stderr(process::Stdio::null());
    }

    let mkfs_fat_result = mkfs_fat_cmd.status();

    if let Err(_) = mkfs_fat_result {
        print_msg("Failed to create FAT image", "error");
        exit(1);
    }
}

fn make_uefi_bootmode() -> io::Result<()> {
    let mut available_ucodes: Vec<String> = Vec::new();

    print_msg("Setting up rEFInd for UEFI booting...");

    for ucode in &ucodes {
        let ucode_path = pacstrap_dir.join("boot").join(ucode);
        if ucode_path.exists() {
            available_ucodes.push(ucode.to_string());
        }
    }

    // Calculate the required FAT image size in bytes
    let efiboot_imgsize = calculate_efiboot_imgsize(&available_ucodes)?;

    // Create a FAT image for the EFI system partition
    make_efibootimg(&efiboot_imgsize)?;

    // Copy systemd-boot EFI binary to the default/fallback boot path
    mcopy_efi_binary("refind_x64.efi", "::/EFI/BOOT/BOOTx64.EFI")?;

    mmd_efi_dir("drivers_x64")?;
    mcopy_efi_binary("iso9660_x64.efi", "::/EFI/BOOT/drivers_x64/")?;
    mcopy_efi_binary("ext4_x64.efi", "::/EFI/BOOT/drivers_x64/")?;

    mmd_efi_dirs(&["icons", "fonts", "themes/orchiis", "themes/orchiis/icons", "themes/orchiis/fonts"])?;

    mcopy_efi_directory("icons", "::/EFI/BOOT/")?;
    mcopy_efi_directory("fonts", "::/EFI/BOOT/")?;

    mcopy_efi_directory("themes/orchiis", "::/EFI/BOOT/themes/")?;
    mcopy_efi_directory("themes/orchiis/fonts", "::/EFI/BOOT/themes/orchiis/")?;
    mcopy_efi_directory("themes/orchiis/icons", "::/EFI/BOOT/themes/orchiis/")?;

    for conf in fs::read_dir(defpath.join("efiboot"))? {
        let conf_path = conf?.path();
        let conf_file_name = conf_path.file_name().unwrap().to_str().unwrap();
        let conf_dest = format!("::/EFI/BOOT/{}", conf_file_name);

        let sed_command = format!(
            "s|%ARCHISO_LABEL%|{}|g; s|%INSTALL_DIR%|{}|g; s|%ARCH%|{}|g",
            iso_label, install_dir, arch
        );

        let sed_output = Command::new("sed")
            .arg(&sed_command)
            .arg(conf_path)
            .output()?;

        mcopy_file_from_memory(&sed_output.stdout, &conf_dest)?;
    }

    mcopy_file("efiboot/startup.nsh", "::/")?;

    if pacstrap_dir.join("usr/share/edk2-shell/x64/Shell_Full.efi").exists() {
        mcopy_efi_binary("Shell_Full.efi", "::/shellx64.efi")?;
    }

    print_msg("Done! rEFInd set up for UEFI booting successfully.");

    // Make kernel and initramfs available in the root system partition.
    let boot_dir = isofs_dir.join(install_dir).join("boot").join(arch);
    fs::create_dir_all(&boot_dir)?;

    for entry in fs::read_dir(pacstrap_dir.join("boot"))? {
        let entry_path = entry?.path();
        let entry_file_name = entry_path.file_name().unwrap().to_str().unwrap();
        if entry_file_name.starts_with("initramfs-") || entry_file_name.starts_with("vmlinuz-") {
            let dest = boot_dir.join(entry_file_name);
            fs::copy(&entry_path, &dest)?;
        }
    }

    for ucode_image in &ucodes {
        let ucode_path = pacstrap_dir.join("boot").join(ucode_image);
        if ucode_path.exists() {
            let dest = boot_dir.join(ucode_image);
            fs::copy(ucode_path, dest)?;

            let license_dir = pacstrap_dir.join("usr/share/licenses").join(ucode_image.trim_end_matches(".img"));
            if license_dir.exists() {
                let dest_license_dir = boot_dir.join("licenses").join(ucode_image.trim_end_matches(".img"));
                fs::create_dir_all(&dest_license_dir)?;

                for entry in fs::read_dir(license_dir)? {
                    let entry_path = entry?.path();
                    let entry_file_name = entry_path.file_name().unwrap().to_str().unwrap();
                    let dest = dest_license_dir.join(entry_file_name);
                    fs::copy(entry_path, dest)?;
                }
            }
        }
    }

    // Additionally set up system-boot in ISO 9660.
    print_msg("Preparing an /EFI directory for the ISO 9660 file system...");
    let efi_dir = isofs_dir.join("EFI");
    fs::create_dir_all(&efi_dir)?;

    if pacstrap_dir.join("usr/share/edk2-shell/x64/Shell_Full.efi").exists() {
        fs::copy(
            pacstrap_dir.join("usr/share/edk2-shell/x64/Shell_Full.efi"),
            efi_dir.join("shellx64.efi"),
        )?;
    }

    // Copy kernel and initramfs to FAT image.
    print_msg("Preparing kernel and initramfs for the FAT file system...");
    let fat_image_dir = format!("::/{}/boot/{}", install_dir, arch);
    mmd_efi_dirs(&[&fat_image_dir])?;

    for entry in fs::read_dir(pacstrap_dir.join("boot"))? {
        let entry_path = entry?.path();
        let entry_file_name = entry_path.file_name().unwrap().to_str().unwrap();
        if entry_file_name.starts_with("initramfs-") || entry_file_name.starts_with("vmlinuz-") {
            let dest = format!("{}/{}", fat_image_dir, entry_file_name);
            mcopy_file(&entry_path, &dest)?;
        }
    }

    for ucode_image in &ucodes {
        let ucode_path = pacstrap_dir.join("boot").join(ucode_image);
        if ucode_path.exists() {
            let dest = format!("{}/boot/{}", install_dir, ucode_image);
            mcopy_file(&ucode_path, &dest)?;
        }
    }

    Ok(())
}

fn calculate_efiboot_imgsize(
    pacstrap_dir: &str,
    defpath: &str,
    available_ucodes: &[PathBuf],
) -> io::Result<u64> {
    let mut efiboot_imgsize: u64 = 0;

    //Calcular o efiboot_imgsize com base em diretórios, dúvida para o Leandro
    // ...

    Ok(efiboot_imgsize)
}

fn mkchecksum() -> io::Result<()> {
    print_msg("Creating checksum file for self-test...")?;

    let isofs_dir = &isofs_dir;
    let install_dir = &install_dir;
    let arch = &arch;

    let old_pwd = env::current_dir()?;
    let iso_root_dir = isofs_dir.join(install_dir).join(arch);

    env::set_current_dir(&iso_root_dir)?;

    if iso_root_dir.join("airootfs.sfs").exists() {
        let output = Command::new("sha512sum")
            .arg("airootfs.sfs")
            .output()?;
        let sha512sum = output.stdout;
        std::fs::write(iso_root_dir.join("airootfs.sha512"), sha512sum)?;
    } else if iso_root_dir.join("airootfs.erofs").exists() {
        let output = Command::new("sha512sum")
            .arg("airootfs.erofs")
            .output()?;
        let sha512sum = output.stdout;
        std::fs::write(iso_root_dir.join("airootfs.sha512"), sha512sum)?;
    }

    env::set_current_dir(old_pwd)?;

    Ok(())
}
