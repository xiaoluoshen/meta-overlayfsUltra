#!/system/bin/sh
# meta-overlayfsUltra — Self Uninstall Script
# Called when meta-overlayfsUltra itself is uninstalled.
# Cleans up the ext4 image and mount point.

MODDIR="${0%/*}"
MNT_DIR="$MODDIR/mnt"
IMG_FILE="$MODDIR/modules.img"

# Unmount the ext4 image if mounted
if mountpoint -q "$MNT_DIR" 2>/dev/null; then
    umount "$MNT_DIR" 2>/dev/null
fi

# Remove the image and mount point
rm -f "$IMG_FILE"
rmdir "$MNT_DIR" 2>/dev/null

# Remove the metamodule symlink
rm -f /data/adb/metamodule
