use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;

fn main() {
    let args: Vec<String> = env::args().collect();
    let mut image = String::new();
    let mut oddimage = String::new();
    let mut accessibility = false;
    let mut boot_type = String::from("bios");
    let mut mediatype = String::from("cdrom");
    let mut secure_boot = String::from("off");
    let mut display = String::from("sdl");
    let mut qemu_options: Vec<String> = Vec::new();
    let mut working_dir = String::new();

    if args.len() > 1 {
        let mut i = 1;
        while i < args.len() {
            match args[i].as_str() {
                "-a" => {
                    accessibility = true;
                }
                "-b" => {
                    boot_type = String::from("bios");
                }
                "-c" => {
                    if i + 1 < args.len() {
                        i += 1;
                        oddimage = args[i].clone();
                    }
                }
                "-d" => {
                    mediatype = String::from("hd");
                }
                "-h" => {
                    print_help();
                    return;
                }
                "-i" => {
                    if i + 1 < args.len() {
                        i += 1;
                        image = args[i].clone();
                    }
                }
                "-u" => {
                    boot_type = String::from("uefi");
                }
                "-s" => {
                    secure_boot = String::from("on");
                }
                "-v" => {
                    display = String::from("none");
                    qemu_options.push(String::from("-vnc"));
                    qemu_options.push(String::from("vnc=0.0.0.0:0,vnc=[::]:0"));
                }
                _ => {
                    println!("Error: Opção incorreta. Tente 'qemu.sh -h'.");
                    return;
                }
            }
            i += 1;
        }
    } else {
        print_help();
        return;
    }

    check_image(&image);

    working_dir = mktemp_working_dir();

    // preciso realizar a implementação
}

fn print_help() {
    let usagetext = r#"Usage:
    qemu.sh [options]
Options:
    -a              set accessibility support using brltty
    -b              set boot type to 'BIOS' (default)
    -d              set image type to hard disk instead of optical disc
    -h              print help
    -i [image]      image to boot into
    -s              use Secure Boot (only relevant when using UEFI)
    -u              set boot type to 'UEFI'
    -v              use VNC display (instead of default SDL)
    -c [image]      attach an additional optical disc image (e.g. for cloud-init)
Example:
    Run an image using UEFI:
    $ qemu.sh -u -i archiso-2020.05.23-x86_64.iso"#;

    println!("{}", usagetext);
}

fn cleanup_working_dir(working_dir: &str) {
    // preciso realizar a implementação
}

fn copy_ovmf_vars(working_dir: &str) {
   // preciso realizar a implementação
}

fn check_image(image: &str) {
   // preciso realizar a implementação
}

fn run_image(
    boot_type: &str,
    image: &str,
    oddimage: &str,
    accessibility: bool,
    mediatype: &str,
    secure_boot: &str,
    display: &str,
    qemu_options: &[String],
    working_dir: &str,
) {
    // preciso realizar a implementação
}

fn mktemp_working_dir() -> String {
    // preciso realizar a implementação
    String::new()
}
