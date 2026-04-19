#!/system/bin/sh
# meta-overlayfsUltra — Installation Script
# Selects the correct architecture binary and creates the ext4 image.

ui_print "- meta-overlayfsUltra installer"
ui_print "- Detecting device architecture..."

ABI=$(grep_get_prop ro.product.cpu.abi)
ui_print "- ABI: $ABI"

case "$ABI" in
    arm64-v8a)
        ARCH_BINARY="meta-overlayfsUltra-aarch64"
        REMOVE_BINARY="meta-overlayfsUltra-x86_64"
        ui_print "- Architecture: ARM64"
        ;;
    x86_64)
        ARCH_BINARY="meta-overlayfsUltra-x86_64"
        REMOVE_BINARY="meta-overlayfsUltra-aarch64"
        ui_print "- Architecture: x86_64"
        ;;
    *)
        abort "! Unsupported architecture: $ABI"
        ;;
esac

if [ ! -f "$MODPATH/$ARCH_BINARY" ]; then
    abort "! Binary not found: $ARCH_BINARY"
fi

mv "$MODPATH/$ARCH_BINARY" "$MODPATH/meta-overlayfsUltra" || abort "! Failed to rename binary"
rm -f "$MODPATH/$REMOVE_BINARY"
chmod 755 "$MODPATH/meta-overlayfsUltra" || abort "! Failed to set permissions"
ui_print "- Binary installed"

# ---- Create or reuse ext4 image ----
IMG_FILE="$MODPATH/modules.img"
IMG_SIZE_MB=2048
EXISTING_IMG="/data/adb/modules/$MODID/modules.img"

if [ -f "$EXISTING_IMG" ]; then
    ui_print "- Reusing existing modules image..."
    "$MODPATH/meta-overlayfsUltra" xcp "$EXISTING_IMG" "$IMG_FILE" || \
        abort "! Failed to copy existing image"
else
    ui_print "- Creating ${IMG_SIZE_MB}MB ext4 image (sparse)..."
    truncate -s ${IMG_SIZE_MB}M "$IMG_FILE" || abort "! Failed to create image"
    # Format without journal to avoid jbd2 sysfs node (stealth)
    /system/bin/mke2fs -t ext4 -O ^has_journal -F "$IMG_FILE" >/dev/null 2>&1 || \
        abort "! Failed to format ext4 image"
    ui_print "- Image created"
fi

# Apply correct SELinux context to image file
chcon u:object_r:ksu_file:s0 "$IMG_FILE" 2>/dev/null

ui_print "- Installation complete"
ui_print "- Reboot to activate meta-overlayfsUltra"
