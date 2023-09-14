use std::env;
use std::path::{Path, PathBuf};
use std::process::Command;
use chrono::Utc;

fn main() {
    let iso_name = "luminus-main";
    let iso_label = format!("LUMINUS_{}", Utc::now().format("%Y%m"));
    let iso_publisher = "Luminus OS <https://luminusos.github.io/>";
    let iso_application = "Luminus OS";
    let iso_version = Utc::now().format("%Y.%m.%d").to_string();
    let install_dir = "luminus";
    let arch = "x86_64";
    let packages: Vec<String> = Vec::new();
    let defpath = env::current_dir().expect("Failed to get current directory");
    let work_dir = defpath.join("work");
    let isofs_dir = work_dir.join("iso");
    let pacstrap_dir = work_dir.join(arch).join("airootfs");
    let out_dir = defpath.join("out");
    let pacman_conf = pacstrap_dir.join("etc").join("pacman.conf");
}
