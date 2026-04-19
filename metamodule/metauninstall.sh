#!/system/bin/sh
# meta-overlayfsUltra — Module Uninstall Hook
# Called when a regular module is uninstalled.
# Cleans up the module's content directory from the ext4 image.

MODULE_ID="$1"
MODDIR="${0%/*}"
MNT_DIR="$MODDIR/mnt"

if [ -z "$MODULE_ID" ]; then
    exit 0
fi

# Remove module content from the mounted ext4 image
if [ -d "$MNT_DIR/$MODULE_ID" ]; then
    rm -rf "$MNT_DIR/$MODULE_ID"
fi
