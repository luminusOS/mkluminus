use std::fs;
use std::fs::File;
use std::io::{self, Write};
use std::path::Path;
use std::process::Command;
use std::os::unix::fs::PermissionsExt;
// preciso verificar as variáveis de ambiente
const PACSTRAP_DIR: &str = pacstrap_dir.to_str().unwrap();
const DEPHANT: &str = install_dir;
const ISO_VERSION: &str = iso_version.as_str();
const ISO_NAME: &str = iso_name;
const INSTALL_DIR: &str = install_dir;

/*const PACSTRAP_DIR: &str = " ";
const DEPHANT: &str = " ";
const ISO_VERSION: &str = " ";
const ISO_NAME: &str = " ";
const INSTALL_DIR: &str " ";*/

fn print_msg(message: &str, level: &str){
    println!("{}:{}", level, message);
}

fn make_custom_airootfs() -> io::Result<()>{
    let file_permissions: std::collections::HashMap<String,String> = // declaras as file_permissions


    fs:: create_dir_all(PACSTRAP_DIR);

    if let Ok(entries) = fs::read_dir(format!("{}/airootfs", DEPHANT)){
        print_msg("Copying custom airootfs files...", "info");
        for entry in entries {
            let entry = entry?;
            let filename = entry.file_name();
            let filename_str = filenameto_string_lossy().to_string();
            if let Some(permissions) = file_permissions.get(&filename_str) {
                if!destination_str.starts_with(PACSTRAP_DIR){
                    print_msg(
                        &format!(
                            "Failed to set permissions on '{}' . Outside of valid path", destination_str
                        ),
                        "error",
                    );
                    continue;
                }
                if entry.file_type()?.is_dir(){
                    fs::create_dir_all(&destination)?;
                    Command:: new("cp")
                        .arg("-rnT")
                        .arg(format!("{}/.", DEPHANT))
                        .arg(&destination_str)
                        .spawn()?;
                    set_permissions(&destination_str, &permissions)?;
                } else {
                    Command::new("cp")
                        .arg("-n")
                        .arg("--preserve=mode,timestamps,links")
                        .arg(format!("{}/{}", DEPHANT,filename_str))
                        .arg(&destination_str)
                        .spawn()?;
                    set_permissions(&destination_str, &permissions)?;
                }
            }
        }
        print_msg("Successfuly made custom airootfs!", "info");
    }
    Ok(())
}

fn set_permissions(path: &str, permissions: &str) -> io::Result<()> {
    let parts: Vec<&str> =permissions.split(':').collect();
    let owner = parts[0];
    let group = parts[1];
    let mode = u32::from_str_radix(parts[2],8)?;

    let path = path::new(path);
    let metadta = fs::metadata(path);

    let mut permissions = metadata.permissions();
    permissions.set_mode(mode);

    let  uid =  owner.parse::<u32>().or_else(|_|{
        let output = Command::new("id").arg("-u").arg(owner).output()?;
        String::from_utf8(output.stdout).trim().parse::<u32>()
    })?;

    let  gid =  owner.parse::<u32>().or_else(|_|{
        let output = Command::new("id").arg("-g").arg(group).output()?;
        String::from_utf8(output.stdout).trim().parse::<u32>()
    })?;

    permissions.set_uid(uid);
    permissions.set_gid(gid);

    fs::set_permissions(path, permissions)?:

    Ok(())
}

fn make_version() -> io:: Result<()> {
    let os_release_path =  format!("{}/etc/os-release", PACSTRAP_DIR);

    print_msg("Creating version files...", "info");

    if let Ok(mut file) = File::create(format!("{}/version",PACSTRAP_DIR)){
        file.Write_all(ISO_VERSION.as_bytes())?;
    }

    fs::create_dir_all(format!("{}/{}/{}", DEPHANT, ISO_NAME, INSTALL_DIR))?;

    if let Ok(mut file) = 
        File::create(format!("{}/{}/{}/version", DEFPATH, ISO_NAME, INSTALL_DIR))
        {
            file.Write_all(ISO_VERSION.as_bytes())?;
        }

    if let OK(mut file) = 
    FIle::create(format!("{}/{}/{}/grubenv", DEFPATH, ISO_NAME, INSTALL_DIR))
    {
        let grubenv_content = format!(
            "# GRUB Environment Block\nNAME={}\nVERSION={}\n{}",
            ISO_NAME,
            ISO_VERSION,
            "#".repeat(1024)
        );
        file.Write_all(grubenv_content.as_bytes())?;
    }

    if let Ok(mut file) = File::create(os_release_path.clone()) {
        file.set_len(0)?;
        file.Write_all(format!("IMAGE_ID={}\nIMAGE_VERSION={}\n", ISO_NAME, ISO_VERSION).as_bytes())?;
    } else if let Ok(mut file) = File::create(format!("{}/usr/lib/os-release", PACSTRAP_DIR)){
        file.set_len(0)?; // Truncate the file
        file.write_all(format!("IMAGE_ID={}\nIMAGE_VERSION={}\n", ISO_NAME, ISO_VERSION).as_bytes())?;
    } else {
        print_msg(
            &format!("os-release file '{}' is outside of valid path.", os_release_path),
            "error",
        );
    }

    Ok(());
}

fn make_customize_airootfs(pacstrap_dir: &str, defpath: &str) {
    if let Ok(passwd_file) = fs::File::open(format!("{}/airootfs/etc/passwd", defpath)) {
        let passwd_lines = io::BufReader::new(passwd_file).lines();

        for line in passwd_lines.filter_map(Result::ok) {
            let fields: Vec<&str> = line.split(':').collect();
            
            if fields.len() >= 6 {
                let uid = match fields[2].parse::<u32>() {
                    Ok(uid) => uid,
                    Err(_) => continue,
                };
                
                let home_dir = fields[5];
                
                if uid >= 1000 && uid < 60000 && home_dir != "/" && !home_dir.is_empty() {
                    let home_path = format!("{}{}", pacstrap_dir, home_dir);
                    
                    if home_path.starts_with(&pacstrap_dir) {
                        if let Err(_) = fs::create_dir_all(&home_path) {
                            print_msg(
                                &format!(
                                    "Failed to create directory '{}'",
                                    home_path
                                ),
                                "error"
                            );
                            continue;
                        }
                        
                        if let Err(_) = Command::new("cp")
                            .arg("-dnRT")
                            .arg("--preserve=mode,timestamps,links")
                            .arg(format!("{}/etc/skel/.", pacstrap_dir))
                            .arg(&home_path)
                            .spawn()
                        {
                            print_msg(
                                &format!(
                                    "Failed to copy files to '{}'",
                                    home_path
                                ),
                                "error"
                            );
                            continue;
                        }
                        
                        if let Err(_) = fs::set_permissions(&home_path, fs::Permissions::from_mode(0o750)) {
                            print_msg(
                                &format!(
                                    "Failed to set permissions on '{}'",
                                    home_path
                                ),
                                "error"
                            );
                        }
                        
                        if let Err(_) = Command::new("chown")
                            .arg("-hR")
                            .arg(format!("{}:{}", fields[2], fields[3]))
                            .arg(&home_path)
                            .spawn()
                        {
                            print_msg(
                                &format!(
                                    "Failed to change ownership of '{}'",
                                    home_path
                                ),
                                "error"
                            );
                        }
                    } else {
                        print_msg(
                            &format!(
                                "Failed to set permissions on '{}'. Outside of valid path.",
                                home_path
                            ),
                            "error",
                        );
                    }
                }
            }
        }
    }

    for script in glob::glob(&format!("{}{}", pacstrap_dir, "/root/scripts/*.sh")).unwrap() {
        if let Ok(script_path) = script {
            if script_path.exists() {
                let script_name = script_path.file_name().unwrap().to_string_lossy();
                print_msg(&format!("Running '{}' in chroot...", &script_name), "info");
                
                if let Err(_) = Command::new("chmod")
                    .arg("+x")
                    .arg(&script_path)
                    .spawn()
                {
                    print_msg(
                        &format!("Failed to make '{}' executable", &script_name),
                        "error"
                    );
                    continue;
                }
                
                if let Err(_) = Command::new("arch-chroot")
                    .arg(&pacstrap_dir)
                    .arg(&format!("/root/scripts/{}", &script_name))
                    .spawn()
                {
                    print_msg(
                        &format!("Failed to run '{}'", &script_name),
                        "error"
                    );
                }
                
                fs::remove_file(&script_path).unwrap_or_else(|_| {
                    print_msg(&format!("Failed to remove '{}'", &script_name), "error");
                });
            }
        }
    }
}

fn cleanup_pacstrap_dir(pacstrap_dir: &str, defpath: &str) {
    print_msg("Cleaning up in pacstrap location...", "info");

    if let Ok(boot_dir) = fs::read_dir(format!("{}/boot", pacstrap_dir)) {
        for entry in boot_dir.filter_map(Result::ok) {
            fs::remove_file(entry.path()).unwrap_or_else(|_| {
                print_msg(
                    &format!("Failed to delete file '{}'", entry.path().display()),
                    "error"
                );
            });
        }
    }

    if let Ok(pacman_dir) = fs::read_dir(format!("{}/var/lib/pacman", pacstrap_dir)) {
        for entry in pacman_dir.filter_map(Result::ok) {
            if entry.file_type().unwrap_or_default().is_file() {
                fs::remove_file(entry.path()).unwrap_or_else(|_| {
                    print_msg(
                        &format!("Failed to delete file '{}'", entry.path().display()),
                        "error"
                    );
                });
            }
        }
    }

    fs::remove_dir_all(format!("{}/var/lib/pacman/sync", pacstrap_dir)).unwrap_or_else(|_| {
        print_msg("Failed to delete pacman database sync cache", "error");
    });

    if let Ok(pacman_cache_dir) = fs::read_dir(format!("{}/var/cache/pacman/pkg", pacstrap_dir)) {
        for entry in pacman_cache_dir.filter_map(Result::ok) {
            if entry.file_type().unwrap_or_default().is_file() {
                fs::remove_file(entry.path()).unwrap_or_else(|_| {
                    print_msg(
                        &format!("Failed to delete file '{}'", entry.path().display()),
                        "error"
                    );
                });
            }
        }
    }

    if let Ok(log_dir) = fs::read_dir(format!("{}/var/log", pacstrap_dir)) {
        for entry in log_dir.filter_map(Result::ok) {
            if entry.file_type().unwrap_or_default().is_file() {
                fs::remove_file(entry.path()).unwrap_or_else(|_| {
                    print_msg(
                        &format!("Failed to delete file '{}'", entry.path().display()),
                        "error"
                    );
                });
            }
        }
    }

    if let Ok(tmp_dir) = fs::read_dir(format!("{}/var/tmp", pacstrap_dir)) {
        for entry in tmp_dir.filter_map(Result::ok) {
            fs::remove_dir_all(entry.path()).unwrap_or_else(|_| {
                print_msg(
                    &format!("Failed to delete directory '{}'", entry.path().display()),
                    "error"
                );
            });
        }
    }

    // Implement code to delete package pacman related files.
    
    let machine_id_path = format!("{}/etc/machine-id", pacstrap_dir);
    fs::write(&machine_id_path, "").unwrap_or_else(|_| {
        print_msg("Failed to create an empty /etc/machine-id", "error");
    });
}

fn mkairootfs_squashfs(pacstrap_dir: &str) {
    let image_path = format!("{}/airootfs.sfs", pacstrap_dir);

    if !Path::new(pacstrap_dir).exists() {
        print_msg(&format!("The path '{}' does not exist", pacstrap_dir), "error");
        exit(1);
    }

    if Path::new(&image_path).exists() {
        fs::remove_file(&image_path).unwrap_or_else(|_| {
            print_msg(
                &format!("Failed to delete existing file '{}'", &image_path),
                "error"
            );
        });
    }

    if let Err(_) = fs::create_dir_all(Path::new(&image_path).parent().unwrap()) {
        print_msg(&format!("Failed to create directory '{}'", &image_path), "error");
        exit(1);
    }

    print_msg("Creating SquashFS image, this may take some time...", "info");

    let mksquashfs = if env::var("silent_build") == Ok("yes".to_string()) {
        Command::new("mksquashfs")
            .arg(pacstrap_dir)
            .arg(&image_path)
            .arg("-noappend")
            .arg("-no-progress")
            .stdout(process::Stdio::null())
            .stderr(process::Stdio::null())
            .spawn()
    } else {
        Command::new("mksquashfs")
            .arg(pacstrap_dir)
            .arg(&image_path)
            .arg("-noappend")
            .stdout(process::Stdio::null())
            .stderr(process::Stdio::null())
            .spawn()
    };

    if let Err(_) = mksquashfs {
        print_msg("Failed to create SquashFS image", "error");
        exit(1);
    }

    fn mkchecksum() -> io::Result<()> {
        print_msg("Creating checksum file for self-test...");
    
        let isofs_dir = &isofs_dir;
        let install_dir = &install_dir;
        let arch = &arch;
    
        let old_pwd = env::current_dir()?;
        let iso_root_dir = isofs_dir.join(install_dir).join(arch);
    
        env::set_current_dir(&iso_root_dir)?;
    
        if iso_root_dir.join("airootfs.sfs").exists() {
            let mut sha512sum_file = File::create(iso_root_dir.join("airootfs.sha512"))?;
            let output = Command::new("sha512sum")
                .arg("airootfs.sfs")
                .output()?;
            sha512sum_file.write_all(&output.stdout)?;
        } else if iso_root_dir.join("airootfs.erofs").exists() {
            let mut sha512sum_file = File::create(iso_root_dir.join("airootfs.sha512"))?;
            let output = Command::new("sha512sum")
                .arg("airootfs.erofs")
                .output()?;
            sha512sum_file.write_all(&output.stdout)?;
        }
    
        env::set_current_dir(old_pwd)?;
    
        Ok(())
    }
    mkchecksum();
}