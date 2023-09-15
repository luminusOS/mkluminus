use std::env;
use std::fs;
use std::io;
use std::path::Path;
use std::process::Command;

fn main() -> io::Result<()> {
    let args: Vec<String> = env::args().collect();
    let mut delete_work_dir = false;
    let mut silent_build = false;
    let mut out_dir = String::new();
    let mut work_dir = String::new();

    for (index, arg) in args.iter().enumerate() {
        match arg.as_str() {
            "-d" => delete_work_dir = true,
            "-o" if index < args.len() - 1 => out_dir = args[index + 1].clone(),
            "-w" if index < args.len() - 1 => work_dir = args[index + 1].clone(),
            "-s" => silent_build = true,
            _ => {}
        }
    }

    // Controle do ambiente
    env::set_var("LC_ALL", "C");
    env::set_var("SOURCE_DATE_EPOCH", &format!("{}", chrono::Utc::now().timestamp()));

    // Declaração de constantes
    let file_permissions = vec![
        ("/etc/shadow", "0:0:400"),
        ("/etc/gshadow", "0:0:400"),
        ("/root", "0:0:750"),
    ];

    // Declaração de constantes somente-leitura
    let ucodes = vec![
        "intel-uc.img",
        "intel-ucode.img",
        "amd-uc.img",
        "amd-ucode.img",
        "early_ucode.cpio",
        "microcode.cpio",
    ];

    let dependencies = vec![
        "pacman-conf",
        "pacstrap",
        "pacman",
        "mkfs.fat",
        "mkfs.ext4",
        "mksquashfs",
        "xorriso",
    ];

    // Definição de funções
    fn usage() {
        println!(
            "usage: build.rs [options]\n\
             options:\n\
             -h                 This message\n\
             -d                 Delete work directory if exists\n\
             -s                 Silent build\n\
             -o [directory]     Change output iso directory\n\
             -w [directory]     Change work directory\n\
             Example:\n\
             Build an Luminus ISO image:\n\
             $ mkluminus -o ~/mkluminus/iso -w ~/mkluminus/work -d -s"
        );
    }

    fn print_msg(message: &str, type_: &str) {
        let datetime = chrono::Utc::now().format("%d/%m/%Y %H:%M:%S");
        match type_ {
            "warn" => println!("\x1B[1;33m{} [WARN] {}\x1B[0m", datetime, message),
            "error" => {
                eprintln!("\x1B[1;31m{} [ERROR] {}\x1B[0m", datetime, message);
                std::process::exit(1);
            }
            _ => println!("\x1B[1;37m{} [INFO] {}\x1B[0m", datetime, message),
        }
    }

    fn verify_dependencies(dependencies: Vec<&str>) -> io::Result<()> {
        let mut missing_dependencies: Vec<&str> = Vec::new();
        for dependency in dependencies.iter() {
            if let Err(_) = Command::new("command").arg("-v").arg(dependency).output() {
                missing_dependencies.push(dependency);
            }
        }
        if !missing_dependencies.is_empty() {
            print_msg(&format!("Missing dependencies: {}", missing_dependencies.join(", ")), "error");
            std::process::exit(1);
        }
        Ok(())
    }

    fn build() -> io::Result<()> {
        // Check if work_dir exists and delete then
        // Necessary for rebuild the iso with base configurations if have any changes.
        // See https://wiki.archlinux.org/index.php/Archiso#Removal_of_work_directory
        if delete_work_dir && fs::metadata(&work_dir).is_ok() {
            print_msg("Deleting work folder...", "");
            let count = remove_dir_all(&work_dir)?.len();
            print_msg(&format!("Successfully deleted {} files", count), "");
        }

        fs::create_dir_all(&work_dir)?;

        verify_dependencies(dependencies)?;

        make_pacman_conf()?;
        make_custom_airootfs()?;
        make_packages()?;
        make_version()?;
        make_customize_airootfs()?;
        make_pkglist()?;
        make_uefi_bootmode()?;
        cleanup_pacstrap_dir()?;
        mkairootfs_squashfs()?;
        build_iso_image()?;

        Ok(())
    }

    // Variáveis
    let source_date_epoch = match env::var("SOURCE_DATE_EPOCH") {
        Ok(val) => val,
        Err(_) => format!("{}", chrono::Utc::now().timestamp()),
    };

    let mut file_permissions_map: std::collections::HashMap<&str, &str> = std::collections::HashMap::new();
    for (path, permissions) in file_permissions.iter() {
        file_permissions_map.insert(path, permissions);
    }

    // Definir variáveis de ambiente
    env::set_var("LC_ALL", "C");
    env::set_var("SOURCE_DATE_EPOCH", source_date_epoch);

    // Chamar função build
    build()?;

    Ok(())
}
