// ============================================================
// meta-overlayfsUltra — Main Entry Point
//
// Sub-commands:
//   (none)   — perform systemless mount (called by metamount.sh)
//   xcp      — sparse-aware file copy  (called by customize.sh)
// ============================================================

#![feature(let_chains)]

use anyhow::Result;
use log::info;

mod defs;
mod mount;
mod stealth;
mod xcp;

fn main() -> Result<()> {
    let args: Vec<String> = std::env::args().collect();

    // ---- Sub-command dispatch ----
    if args.get(1).map(|s| s.as_str()) == Some("xcp") {
        return xcp::run(&args[2..]);
    }

    // ---- Initialise logger ----
    // Default level: info.  Override with RUST_LOG=debug for verbose output.
    env_logger::Builder::new()
        .filter_level(log::LevelFilter::Info)
        .init();

    info!("meta-overlayfsUltra v{}", env!("CARGO_PKG_VERSION"));

    // ---- Stealth: camouflage process name ----
    stealth::camouflage_process_name();

    // ---- Stealth: timing jitter (≤ 20 ms) ----
    stealth::timing_jitter_ms(20);

    // ---- Read directory configuration from environment ----
    // metamount.sh exports these before executing the binary.
    let metadata_dir = std::env::var("MODULE_METADATA_DIR")
        .unwrap_or_else(|_| defs::MODULE_METADATA_DIR.to_string());
    let content_dir = std::env::var("MODULE_CONTENT_DIR")
        .unwrap_or_else(|_| defs::MODULE_CONTENT_DIR.to_string());

    info!("metadata dir : {metadata_dir}");
    info!("content dir  : {content_dir}");

    // ---- Core: mount all enabled modules systemlessly ----
    mount::mount_modules_systemlessly(&metadata_dir, &content_dir)?;

    // ---- Stealth: verify no unexpected paths leak in mountinfo ----
    stealth::verify_mount_stealth();

    info!("mount completed successfully");
    Ok(())
}
