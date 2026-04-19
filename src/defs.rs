// ============================================================
// meta-overlayfsUltra — Constants & Path Definitions
// Ultra-stealth KernelSU MetaModule
// ============================================================

// ---- Dual-directory architecture ----
// Metadata: module.prop / disable / skip_mount markers
pub const MODULE_METADATA_DIR: &str = "/data/adb/modules/";
// Content: actual system/vendor/... overlay trees (inside ext4 image)
pub const MODULE_CONTENT_DIR: &str = "/data/adb/metamodule/mnt/";

// ---- Legacy single-dir fallback ----
pub const _MODULE_DIR: &str = "/data/adb/modules/";

// ---- Status marker filenames ----
pub const DISABLE_FILE_NAME: &str = "disable";
pub const REMOVE_FILE_NAME: &str = "remove";
pub const SKIP_MOUNT_FILE_NAME: &str = "skip_mount";

// ---- Read-write overlay root ----
// Optional upperdir/workdir support for live system edits
pub const SYSTEM_RW_DIR: &str = "/data/adb/modules/.rw/";

// ---- KernelSU overlay source identifier ----
// MUST be "KSU" — required for KernelSU to recognise & manage mounts
pub const KSU_OVERLAY_SOURCE: &str = "KSU";

// ---- Supported partition list ----
pub const PARTITIONS: &[&str] = &["vendor", "product", "system_ext", "odm", "oem"];

// ---- Anti-detection: fake proc entry prefix ----
// When scanning /proc/mounts the source field will show "KSU",
// which is indistinguishable from a stock KernelSU mount.
// No additional label is needed — the source IS the camouflage.
