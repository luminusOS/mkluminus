use std::env;
use std::fs;
use std::path::Path;
use std::process::{self, Command};

fn print_msg(message: &str) {
    println!("{}", message);
}

fn build_iso_image(
    out_dir: &str,
    silent_build: &str,
    iso_name: &str,
    iso_version: &str,
    arch: &str,
    iso_label: &str,
    iso_application: &str,
    iso_publisher: &str,
    work_dir: &str,
    isofs_dir: &str,
) {
    let mut xorrisofs_options: Vec<String> = Vec::new();
    let image_name = format!("{}-{}-{}.iso", iso_name, iso_version, arch);

    if !Path::new(out_dir).exists() {
        if let Err(_) = fs::create_dir_all(out_dir) {
            print_msg("Failed to create the output directory");
            process::exit(1);
        }
    }

    if silent_build == "yes" {
        xorrisofs_options.push("-quiet".to_string());
    }

    if !Path::new(&format!("{}/EFI", isofs_dir)).exists() {
        if let Err(_) = fs::create_dir_all(&format!("{}/EFI", isofs_dir)) {
            print_msg("Failed to create EFI directory");
            process::exit(1);
        }
    }

    if let Err(_) = fs::copy(&format!("{}/efiboot.img", work_dir), &format!("{}/EFI/efiboot.img", isofs_dir)) {
        print_msg("Failed to copy efiboot.img to EFI directory");
        process::exit(1);
    }

    xorrisofs_options.push("-partition_offset".to_string());
    xorrisofs_options.push("16".to_string());
    xorrisofs_options.push("-append_partition".to_string());
    xorrisofs_options.push("2".to_string());
    xorrisofs_options.push("C12A7328-F81F-11D2-BA4B-00A0C93EC93B".to_string());
    xorrisofs_options.push(format!("{}{}", work_dir, "/efiboot.img"));
    xorrisofs_options.push("-appended_part_as_gpt".to_string());
    xorrisofs_options.push("-eltorito-alt-boot".to_string());
    xorrisofs_options.push("-isohybrid-gpt-basdat".to_string());
    xorrisofs_options.push("-no-emul-boot".to_string());
    xorrisofs_options.push("-e".to_string());
    xorrisofs_options.push("--interval:appended_partition_2:all::".to_string());
    xorrisofs_options.push("-eltorito-boot".to_string());
    xorrisofs_options.push("EFI/efiboot.img".to_string());
    xorrisofs_options.push("-eltorito-platform".to_string());
    xorrisofs_options.push("efi".to_string());
    xorrisofs_options.push("-eltorito-catalog".to_string());
    xorrisofs_options.push("EFI/boot.cat".to_string());

    print_msg("Creating ISO image...");

    let mut xorriso_cmd = Command::new("xorriso");
    xorriso_cmd.arg("-as");
    xorriso_cmd.arg("mkisofs");
    xorriso_cmd.arg("-iso-level");
    xorriso_cmd.arg("3");
    xorriso_cmd.arg("-full-iso9660-filenames");
    xorriso_cmd.arg("-joliet");
    xorriso_cmd.arg("-joliet-long");
    xorriso_cmd.arg("-rational-rock");
    xorriso_cmd.arg("-volid");
    xorriso_cmd.arg(iso_label);
    xorriso_cmd.arg("-appid");
    xorriso_cmd.arg(iso_application);
    xorriso_cmd.arg("-publisher");
    xorriso_cmd.arg(iso_publisher);
    xorriso_cmd.args(&xorrisofs_options);
    xorriso_cmd.arg("-output");
    xorriso_cmd.arg(&format!("{}/{}", out_dir, image_name));
    xorriso_cmd.arg(isofs_dir);

    match xorriso_cmd.status() {
        Ok(status) => {
            if status.success() {
                print_msg(&format!("ISO image created in {}/{}", out_dir, image_name));
                if let Ok(output) = xorriso_cmd.output() {
                    io::stdout().write_all(&output.stdout).unwrap();
                }
            } else {
                print_msg("Failed to create ISO image");
                process::exit(1);
            }
        }
        Err(_) => {
            print_msg("Failed to run xorriso");
            process::exit(1);
        }
    }

    let iso_path = format!("{}/{}", out_dir, image_name);
    if let Ok(metadata) = fs::metadata(&iso_path) {
        print_msg(&format!("ISO image size: {:.2} MB", metadata.len() as f64 / 1024.0 / 1024.0));
    } else {
        print_msg("Failed to retrieve ISO image size");
    }
}
