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

fn make_uefi_bootmode(pacstrap_dir: &str, defpath: &str, work_dir: &str) {
    let mut available_ucodes: Vec<PathBuf> = Vec::new();
    print_msg("Setting up rEFInd for UEFI booting...", "info");

    let ucodes = match env::var("ucodes") {
        Ok(val) => val,
        Err(_) => "".to_string(),
    };

    for ucode in ucodes.split_whitespace() {
        if Path::new(&format!("{}/boot/{}", pacstrap_dir, ucode)).exists() {
            available_ucodes.push(PathBuf::from(format!("{}/boot/{}", pacstrap_dir, ucode)));
        }
    }

    let efiboot_imgsize = match calculate_efiboot_imgsize(pacstrap_dir, defpath, &available_ucodes) {
        Ok(size) => size,
        Err(_) => {
            print_msg("Failed to calculate EFI boot image size", "error");
            exit(1);
        }
    };

    make_efibootimg(efiboot_imgsize, work_dir, "no");

    // dúvidas com o Leandro sobre make_uefi_bootmode 
    // ...

    print_msg("Done! rEFInd set up for UEFI booting successfully.", "info");
}

fn calculate_efiboot_imgsize(
    pacstrap_dir: &str,
    defpath: &str,
    available_ucodes: &[PathBuf],
) -> io::Result<u64> {
    let mut efiboot_imgsize: u64 = 0;

    //Calcular o efiboot_imgsize com base em diretórios, dúvida para o Lenadro
    // ...

    Ok(efiboot_imgsize)
}

fn mkchecksum(work_dir: &str, defpath: &str) {
    print_msg("Creating checksum file for self-test...", "info");

    // menor ideia de como faz isso em rust, perguntar para o Leandro
    // ...

}
