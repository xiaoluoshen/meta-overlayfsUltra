#!/system/bin/sh
# meta-overlayfsUltra — Module Install Hook
# Sourced by KernelSU's built-in installer for each regular module.
# Runs AFTER file extraction but BEFORE installation completes.
# This script is NOT called when meta-overlayfsUltra itself is installed.

# Verify module compatibility
if [ -n "$KSU_VER_CODE" ] && [ "$KSU_VER_CODE" -lt 10940 ]; then
    ui_print "! Warning: KernelSU version may not fully support metamodules"
fi

# Perform the standard installation
install_module

ui_print "- meta-overlayfsUltra: module installed via ultra-stealth handler"
