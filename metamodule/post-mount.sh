#!/system/bin/sh
# meta-overlayfsUltra — Post-Mount Script
# Runs after all overlays are applied.
# Restores SELinux contexts on overlaid paths so that
# `ls -Z` output is indistinguishable from stock.

PARTITIONS="system vendor product system_ext odm oem"

for part in $PARTITIONS; do
    TARGET="/$part"
    if mountpoint -q "$TARGET" 2>/dev/null; then
        # Restore contexts recursively (best-effort, silent)
        restorecon -RF "$TARGET" 2>/dev/null &
    fi
done

# Wait for background restorecon jobs (max 5 s)
wait
