#!/system/bin/sh
# meta-overlayfsUltra — Service Script
# Runs in the late_start service phase.
# Performs additional stealth hardening after boot.

MODDIR="${0%/*}"

# ---- Hide module directory from /proc/mounts ----
# The ext4 image mount point is inside MODDIR.
# We do NOT unmount it — we just ensure its SELinux context
# matches a stock path so file-based scanners are not triggered.
MNT_DIR="$MODDIR/mnt"
if mountpoint -q "$MNT_DIR" 2>/dev/null; then
    chcon u:object_r:system_file:s0 "$MNT_DIR" 2>/dev/null
fi

# ---- Ensure binary has no suspicious xattr ----
setfattr -x security.selinux "$MODDIR/meta-overlayfsUltra" 2>/dev/null || true
chcon u:object_r:system_file:s0 "$MODDIR/meta-overlayfsUltra" 2>/dev/null

# Done — no persistent daemon needed
