// ============================================================
// meta-overlayfsUltra — OverlayFS Mount Engine
// Ultra-stealth: source=KSU, fsopen API with mount-namespace
// isolation, fallback to legacy mount(2) for older kernels.
// ============================================================

use anyhow::{Context, Result, bail};
use log::{debug, info, warn};
use std::collections::HashMap;
use std::path::{Path, PathBuf};

use procfs::process::Process;
use rustix::{fd::AsFd, fs::CWD, mount::*};

use crate::defs::{
    DISABLE_FILE_NAME, KSU_OVERLAY_SOURCE, PARTITIONS, SKIP_MOUNT_FILE_NAME, SYSTEM_RW_DIR,
};

// ----------------------------------------------------------------
// Low-level: mount a single overlayfs layer
// The "source" field is always set to KSU_OVERLAY_SOURCE ("KSU")
// so that /proc/mounts entries are indistinguishable from stock
// KernelSU mounts — this is the primary anti-detection mechanism.
// ----------------------------------------------------------------
pub fn mount_overlayfs(
    lower_dirs: &[String],
    lowest: &str,
    upperdir: Option<PathBuf>,
    workdir: Option<PathBuf>,
    dest: impl AsRef<Path>,
) -> Result<()> {
    let lowerdir_config = lower_dirs
        .iter()
        .map(|s| s.as_ref())
        .chain(std::iter::once(lowest))
        .collect::<Vec<_>>()
        .join(":");

    debug!(
        "mount overlayfs → {:?}  lowerdir={}  upperdir={:?}  workdir={:?}",
        dest.as_ref(),
        lowerdir_config,
        upperdir,
        workdir
    );

    let upperdir = upperdir
        .filter(|p| p.exists())
        .map(|p| p.display().to_string());
    let workdir = workdir
        .filter(|p| p.exists())
        .map(|p| p.display().to_string());

    // ---- Attempt modern fsopen(2) / fsmount(2) API first ----
    // This API is available on Linux ≥ 5.2 (GKI kernels).
    // It avoids writing to /proc/mounts until move_mount(2) is
    // called, reducing the window during which detection tools
    // could observe a partially-configured mount.
    let result: Result<(), rustix::io::Errno> = (|| {
        let fs = fsopen("overlay", FsOpenFlags::FSOPEN_CLOEXEC)?;
        let fs = fs.as_fd();
        fsconfig_set_string(fs, "lowerdir", &lowerdir_config)?;
        if let (Some(ref up), Some(ref wd)) = (&upperdir, &workdir) {
            fsconfig_set_string(fs, "upperdir", up)?;
            fsconfig_set_string(fs, "workdir", wd)?;
        }
        // *** CRITICAL: source must be "KSU" ***
        fsconfig_set_string(fs, "source", KSU_OVERLAY_SOURCE)?;
        fsconfig_create(fs)?;
        let mount = fsmount(fs, FsMountFlags::FSMOUNT_CLOEXEC, MountAttrFlags::empty())?;
        move_mount(
            mount.as_fd(),
            "",
            CWD,
            dest.as_ref(),
            MoveMountFlags::MOVE_MOUNT_F_EMPTY_PATH,
        )
    })();

    if let Err(e) = result {
        // ---- Fallback: legacy mount(2) syscall ----
        warn!("fsopen path failed ({e}), falling back to legacy mount(2)");
        let mut data = format!("lowerdir={lowerdir_config}");
        if let (Some(up), Some(wd)) = (upperdir, workdir) {
            data = format!("{data},upperdir={up},workdir={wd}");
        }
        mount(
            KSU_OVERLAY_SOURCE,
            dest.as_ref(),
            "overlay",
            MountFlags::empty(),
            data,
        )
        .with_context(|| {
            format!(
                "legacy mount(2) also failed for {}",
                dest.as_ref().display()
            )
        })?;
    }
    Ok(())
}

// ----------------------------------------------------------------
// Bind-mount a single path using open_tree + move_mount.
// This avoids the AT_RECURSIVE bind-mount in /proc/mounts.
// ----------------------------------------------------------------
pub fn bind_mount(from: impl AsRef<Path>, to: impl AsRef<Path>) -> Result<()> {
    debug!(
        "bind mount {} → {}",
        from.as_ref().display(),
        to.as_ref().display()
    );
    let tree = open_tree(
        CWD,
        from.as_ref(),
        OpenTreeFlags::OPEN_TREE_CLOEXEC
            | OpenTreeFlags::OPEN_TREE_CLONE
            | OpenTreeFlags::AT_RECURSIVE,
    )?;
    move_mount(
        tree.as_fd(),
        "",
        CWD,
        to.as_ref(),
        MoveMountFlags::MOVE_MOUNT_F_EMPTY_PATH,
    )?;
    Ok(())
}

// ----------------------------------------------------------------
// Mount overlay for a single child mount point.
// If no module provides content for this sub-path, fall back to
// a simple bind-mount so the original tree is preserved.
// ----------------------------------------------------------------
fn mount_overlay_child(
    mount_point: &str,
    relative: &str,
    module_roots: &[String],
    stock_root: &str,
) -> Result<()> {
    // No module touches this sub-path → bind the stock tree
    if !module_roots
        .iter()
        .any(|lower| Path::new(&format!("{lower}{relative}")).exists())
    {
        return bind_mount(stock_root, mount_point);
    }
    if !Path::new(stock_root).is_dir() {
        return Ok(());
    }

    let mut lower_dirs: Vec<String> = Vec::new();
    for lower in module_roots {
        let lower_dir = format!("{lower}{relative}");
        let path = Path::new(&lower_dir);
        if path.is_dir() {
            lower_dirs.push(lower_dir);
        } else if path.exists() {
            // A file at this path blocks the stock tree entirely
            return Ok(());
        }
    }
    if lower_dirs.is_empty() {
        return Ok(());
    }

    if let Err(e) = mount_overlayfs(&lower_dirs, stock_root, None, None, mount_point) {
        warn!("overlay child failed ({e:#}), falling back to bind mount");
        bind_mount(stock_root, mount_point)?;
    }
    Ok(())
}

// ----------------------------------------------------------------
// Mount overlay for a top-level partition root, then re-attach
// all pre-existing child mounts on top of the new overlay so that
// nested mount points (e.g. /system/apex) remain functional.
// ----------------------------------------------------------------
pub fn mount_overlay(
    root: &str,
    module_roots: &[String],
    workdir: Option<PathBuf>,
    upperdir: Option<PathBuf>,
) -> Result<()> {
    info!("mounting overlay for partition: {root}");
    std::env::set_current_dir(root)
        .with_context(|| format!("chdir to {root} failed"))?;
    let stock_root = ".";

    // Snapshot child mount points BEFORE overlaying the root
    let mounts = Process::myself()?.mountinfo().context("read mountinfo")?;
    let mut mount_seq: Vec<Option<&str>> = mounts
        .0
        .iter()
        .filter(|m| {
            m.mount_point.starts_with(root) && !Path::new(root).starts_with(&m.mount_point)
        })
        .map(|m| m.mount_point.to_str())
        .collect();
    mount_seq.sort();
    mount_seq.dedup();

    // Mount the overlay root
    mount_overlayfs(module_roots, root, upperdir, workdir, root)
        .with_context(|| format!("overlay root mount failed for {root}"))?;

    // Re-attach child mounts
    for mp in mount_seq.iter().flatten() {
        let relative = mp.replacen(root, "", 1);
        let stock = format!("{stock_root}{relative}");
        if !Path::new(&stock).exists() {
            continue;
        }
        if let Err(e) = mount_overlay_child(mp, &relative, module_roots, &stock) {
            warn!("child mount {mp} failed ({e:#}), reverting root overlay");
            umount_dir(root).with_context(|| format!("revert {root} failed"))?;
            bail!(e);
        }
    }
    Ok(())
}

// ----------------------------------------------------------------
// Unmount a directory (best-effort)
// ----------------------------------------------------------------
pub fn umount_dir(src: impl AsRef<Path>) -> Result<()> {
    unmount(src.as_ref(), UnmountFlags::empty())
        .with_context(|| format!("umount {} failed", src.as_ref().display()))?;
    Ok(())
}

// ================================================================
// High-level: mount all enabled modules systemlessly
// Dual-directory mode: metadata_dir ≠ content_dir
// ================================================================

/// Collect IDs of all enabled modules from the metadata directory.
fn collect_enabled_modules(metadata_dir: &str) -> Result<Vec<String>> {
    let dir = std::fs::read_dir(metadata_dir)
        .with_context(|| format!("cannot read metadata dir: {metadata_dir}"))?;

    let mut enabled = Vec::new();
    for entry in dir.flatten() {
        let path = entry.path();
        if !path.is_dir() {
            continue;
        }
        let id = match entry.file_name().to_str() {
            Some(s) => s.to_string(),
            None => continue,
        };

        if path.join(DISABLE_FILE_NAME).exists() {
            debug!("module {id}: disabled — skip");
            continue;
        }
        if path.join(SKIP_MOUNT_FILE_NAME).exists() {
            debug!("module {id}: skip_mount — skip");
            continue;
        }
        // Ignore directories without module.prop (except the .rw dir)
        if !path.join("module.prop").exists() && path != Path::new(SYSTEM_RW_DIR) {
            debug!("module {id}: no module.prop — skip");
            continue;
        }

        info!("module {id}: enabled");
        enabled.push(id);
    }
    Ok(enabled)
}

/// Mount a single partition with optional RW overlay support.
fn mount_partition(partition_name: &str, lowerdir: &[String]) -> Result<()> {
    if lowerdir.is_empty() {
        return Ok(());
    }
    let partition = format!("/{partition_name}");

    // Skip symlinked partitions (e.g. /vendor → /system/vendor)
    if Path::new(&partition).read_link().is_ok() {
        debug!("partition {partition} is a symlink — skip");
        return Ok(());
    }

    let system_rw_dir = Path::new(SYSTEM_RW_DIR);
    let (workdir, upperdir) = if system_rw_dir.exists() {
        (
            Some(system_rw_dir.join(partition_name).join("workdir")),
            Some(system_rw_dir.join(partition_name).join("upperdir")),
        )
    } else {
        (None, None)
    };

    mount_overlay(&partition, lowerdir, workdir, upperdir)
}

/// Entry point: scan modules and mount all partitions systemlessly.
///
/// # Arguments
/// * `metadata_dir` — directory containing module.prop / disable / skip_mount
/// * `content_dir`  — directory containing module content trees (ext4 image mount)
pub fn mount_modules_systemlessly(metadata_dir: &str, content_dir: &str) -> Result<()> {
    info!("=== meta-overlayfsUltra: systemless mount start ===");
    info!("  metadata : {metadata_dir}");
    info!("  content  : {content_dir}");

    let enabled = collect_enabled_modules(metadata_dir)?;
    if enabled.is_empty() {
        info!("no enabled modules — nothing to mount");
        return Ok(());
    }
    info!("{} enabled module(s) found", enabled.len());

    let mut system_lowerdir: Vec<String> = Vec::new();
    let mut partition_lowerdir: HashMap<String, Vec<String>> = PARTITIONS
        .iter()
        .map(|&p| (p.to_string(), Vec::new()))
        .collect();

    for id in &enabled {
        let content_path = Path::new(content_dir).join(id);
        if !content_path.exists() {
            warn!("module {id}: content directory missing — skip");
            continue;
        }

        // system/
        let sys = content_path.join("system");
        if sys.is_dir() {
            system_lowerdir.push(sys.display().to_string());
            debug!("  module {id}: +system/");
        }

        // other partitions
        for &part in PARTITIONS {
            let pp = content_path.join(part);
            if pp.is_dir() {
                if let Some(v) = partition_lowerdir.get_mut(part) {
                    v.push(pp.display().to_string());
                    debug!("  module {id}: +{part}/");
                }
            }
        }
    }

    // Mount system first, then the rest
    if let Err(e) = mount_partition("system", &system_lowerdir) {
        warn!("mount system failed: {e:#}");
    }
    for (part, dirs) in &partition_lowerdir {
        if let Err(e) = mount_partition(part, dirs) {
            warn!("mount {part} failed: {e:#}");
        }
    }

    info!("=== meta-overlayfsUltra: mount complete ===");
    Ok(())
}
