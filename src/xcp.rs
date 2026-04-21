// ============================================================
// meta-overlayfsUltra — Sparse-aware file copy (xcp sub-command)
//
// Used during module installation to migrate an existing
// modules.img from the old install path to the new MODPATH
// without inflating a sparse ext4 image to its full logical size.
// ============================================================

use anyhow::{Context, Result};
use log::info;
use std::fs::{File, OpenOptions};
use std::io::{Read, Seek, SeekFrom, Write};
use std::path::Path;

const BLOCK_SIZE: usize = 4096;

/// Copy `src` to `dst` preserving sparseness.
/// Blocks that are entirely zero are skipped (seek instead of write)
/// so the destination file remains a sparse file on ext4/f2fs.
pub fn sparse_copy(src: impl AsRef<Path>, dst: impl AsRef<Path>) -> Result<()> {
    let src = src.as_ref();
    let dst = dst.as_ref();
    info!("sparse copy: {} → {}", src.display(), dst.display());

    let mut reader = File::open(src)
        .with_context(|| format!("open source: {}", src.display()))?;
    let file_size = reader
        .seek(SeekFrom::End(0))
        .context("seek to end of source")?;
    reader.seek(SeekFrom::Start(0)).context("seek to start")?;

    let mut writer = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .open(dst)
        .with_context(|| format!("open dest: {}", dst.display()))?;

    let mut buf = vec![0u8; BLOCK_SIZE];
    let mut offset: u64 = 0;

    loop {
        let n = reader.read(&mut buf).context("read block")?;
        if n == 0 {
            break;
        }
        let block = &buf[..n];
        if block.iter().all(|&b| b == 0) {
            // Sparse: seek forward instead of writing zeros
            offset += n as u64;
            writer
                .seek(SeekFrom::Start(offset))
                .context("seek in dest")?;
        } else {
            writer.write_all(block).context("write block")?;
            offset += n as u64;
        }
    }

    // Truncate to exact size to handle the last sparse region
    writer
        .set_len(file_size)
        .context("set_len on dest")?;

    info!("sparse copy complete ({file_size} bytes logical)");
    Ok(())
}

/// Entry point called when the binary is invoked as `meta-overlayfsUltra xcp <src> <dst>`
pub fn run(args: &[String]) -> Result<()> {
    if args.len() < 2 {
        anyhow::bail!("usage: meta-overlayfsUltra xcp <src> <dst>");
    }
    sparse_copy(&args[0], &args[1])
}
