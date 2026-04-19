#!/system/bin/sh
# meta-overlayfsUltra — Module Mount Handler
# Called by KernelSU during post-fs-data phase (step 6).
# Performs dual-directory systemless mounting with stealth hardening.

MODDIR="${0%/*}"
IMG_FILE="$MODDIR/modules.img"
MNT_DIR="$MODDIR/mnt"
RW_ROOT="/data/adb/modules/.rw"
PARTITIONS="system vendor product system_ext odm oem"
BINARY="$MODDIR/meta-overlayfsUltra"

# ---- Minimal logging (writes to kmsg only, not to /sdcard) ----
log() {
    # Prefix is intentionally generic to avoid detection by log scanners
    echo "[ksu_mount] $1" 2>/dev/null
}

# ---- Ensure ext4 image is mounted ----
if ! mountpoint -q "$MNT_DIR" 2>/dev/null; then
    if [ ! -f "$IMG_FILE" ]; then
        log "ERR: image not found"
        exit 1
    fi
    mkdir -p "$MNT_DIR"
    # Apply a stock-looking SELinux context before mounting
    chcon u:object_r:ksu_file:s0 "$IMG_FILE" 2>/dev/null
    mount -t ext4 -o loop,rw,noatime "$IMG_FILE" "$MNT_DIR" || {
        log "ERR: ext4 mount failed"
        exit 1
    }
fi

# ---- Verify binary ----
if [ ! -f "$BINARY" ]; then
    log "ERR: binary not found"
    exit 1
fi

# ---- Apply SELinux contexts to .rw overlay dirs ----
if [ -d "$RW_ROOT" ]; then
    for part in $PARTITIONS; do
        PART_DIR="$RW_ROOT/$part"
        REF="/$part"
        if [ -d "$PART_DIR" ] && [ -e "$REF" ]; then
            chcon --reference="$REF" "$PART_DIR" 2>/dev/null
            [ -d "$PART_DIR/upperdir" ] && chcon --reference="$PART_DIR" "$PART_DIR/upperdir" 2>/dev/null
            [ -d "$PART_DIR/workdir"  ] && chcon --reference="$PART_DIR" "$PART_DIR/workdir"  2>/dev/null
        fi
    done
fi

# ---- Export dual-directory paths for the Rust binary ----
export MODULE_METADATA_DIR="/data/adb/modules"
export MODULE_CONTENT_DIR="$MNT_DIR"

# ---- Execute mount binary ----
# RUST_LOG is intentionally unset in production to suppress output
"$BINARY"
EXIT_CODE=$?

[ $EXIT_CODE -ne 0 ] && log "ERR: mount binary exited $EXIT_CODE"
exit $EXIT_CODE
