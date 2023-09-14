use std::env;
use std::fs;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::{self, Command};

fn print_msg(message: &str) {
    println!("{}", message);
}

fn make_pacman_conf(pacman_conf: &str, pacstrap_dir: &str, work_dir: &str) {
    let cache_dirs: String;
    let system_cache_dirs: String;
    let profile_cache_dirs: String;

    let pacman_conf_path = Path::new(pacman_conf);
    let real_pacman_conf = match fs::canonicalize(pacman_conf_path) {
        Ok(path) => path,
        Err(_) => {
            print_msg("Failed to resolve the real path of pacman_conf.");
            process::exit(1);
        }
    };

    let pacman_conf_content = match fs::read_to_string(&real_pacman_conf) {
        Ok(content) => content,
        Err(_) => {
            print_msg("Failed to read pacman_conf file.");
            process::exit(1);
        }
    };

    system_cache_dirs = run_pacman_conf_command("CacheDir");
    profile_cache_dirs = run_pacman_conf_command_with_config("CacheDir", pacman_conf);

    if profile_cache_dirs != "/var/cache/pacman/pkg" && system_cache_dirs != profile_cache_dirs {
        cache_dirs = profile_cache_dirs;
    } else {
        cache_dirs = system_cache_dirs;
    }

    print_msg("Copying custom pacman.conf to work directory...");
    print_msg(&format!("Using pacman CacheDir: {}", cache_dirs));

    let pacman_conf_content = pacman_conf_content
        .lines()
        .filter(|line| {
            !line.contains("CacheDir")
                && !line.contains("DBPath")
                && !line.contains("HookDir")
                && !line.contains("LogFile")
                && !line.contains("RootDir")
        })
        .collect::<Vec<&str>>()
        .join("\n");

    let updated_pacman_conf = format!(
        "{}\nCacheDir = {}\nHookDir = {}/etc/pacman.d/hooks/",
        pacman_conf_content, cache_dirs, pacstrap_dir
    );

    let pacman_conf_path = Path::new(&work_dir).join("pacman.conf");
    if let Err(_) = fs::write(&pacman_conf_path, &updated_pacman_conf) {
        print_msg("Failed to write updated pacman.conf to the work directory.");
        process::exit(1);
    }
}

fn run_pacman_conf_command(command: &str) -> String {
    let output = match Command::new("pacman-conf").arg(command).output() {
        Ok(output) => output,
        Err(_) => {
            print_msg("Failed to run pacman-conf command.");
            process::exit(1);
        }
    };

    let stdout = String::from_utf8_lossy(&output.stdout);
    stdout.trim().to_string()
}

fn run_pacman_conf_command_with_config(command: &str, config_file: &str) -> String {
    let output = match Command::new("pacman-conf").arg("--config").arg(config_file).arg(command).output() {
        Ok(output) => output,
        Err(_) => {
            print_msg("Failed to run pacman-conf command with config.");
            process::exit(1);
        }
    };

    let stdout = String::from_utf8_lossy(&output.stdout);
    stdout.trim().to_string()
}

fn make_packages(pacman_conf: &str, pacstrap_dir: &str, work_dir: &str) {
    print_msg(&format!("Installing packages to '{}'", pacstrap_dir));

    let mut packages: Vec<String> = Vec::new();
    let package_files = match fs::read_dir(format!("{}/packages", work_dir)) {
        Ok(files) => files,
        Err(_) => {
            print_msg("Failed to read package files.");
            process::exit(1);
        }
    };

    for file in package_files {
        if let Ok(file) = file {
            let pkg_file = file.path();
            let file_name = pkg_file.file_name().unwrap_or_default().to_string_lossy().to_string();

            let package_list = match fs::read_to_string(&pkg_file) {
                Ok(content) => content,
                Err(_) => {
                    print_msg(&format!("Failed to read package list from {}", file_name));
                    process::exit(1);
                }
            };

            let packages_from_file: Vec<String> = package_list
                .lines()
                .filter(|line| !line.starts_with('#') && !line.is_empty())
                .map(|s| s.to_string())
                .collect();

            packages.extend(packages_from_file);
        }
    }

    // Unset TMPDIR to work around https://bugs.archlinux.org/task/70580
    let mut pacstrap_cmd = Command::new("pacstrap");
    pacstrap_cmd.arg("-C").arg(format!("{}/pacman.conf", work_dir));
    pacstrap_cmd.arg("-c").arg("-G").arg("-M");
    pacstrap_cmd.arg("--").arg(pacstrap_dir);
    pacstrap_cmd.args(&packages);

    if env::var("silent_build") == Ok("yes".to_string()) {
        pacstrap_cmd.stdout(process::Stdio::null());
        pacstrap_cmd.stderr(process::Stdio::null());
    }

    match pacstrap_cmd.status() {
        Ok(status) => {
            if status.success() {
                print_msg("Done! Packages installed successfully.");
            } else {
                print_msg("Failed to install packages.");
                process::exit(1);
            }
        }
        Err(_) => {
            print_msg("Failed to run pacstrap.");
            process::exit(1);
        }
    }
}

fn make_pkglist(pacstrap_dir: &str, isofs_dir: &str) {
    print_msg("Creating a list of installed packages on the live environment...");
    let pkglist_path = Path::new(isofs_dir).join(format!("{}/pkglist.txt", pacstrap_dir));

    let pacman_cmd = format!(
        "pacman -Q --sysroot {} > {}",
        pacstrap_dir,
        pkglist_path.to_string_lossy()
    );

    let pacman_cmd = match Command::new("sh").arg("-c").arg(&pacman_cmd).status() {
        Ok(status) => status,
        Err(_) => {
            print_msg("Failed to run pacman to create pkglist.");
            process::exit(1);
        }
    };

    if !pacman_cmd.success() {
        print_msg("Failed to create pkglist.");
        process::exit(1);
    }
}
