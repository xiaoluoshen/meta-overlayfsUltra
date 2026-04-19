#!/usr/bin/env bash
# meta-overlayfsUltra — Build Script
# Builds release binaries for aarch64 and x86_64 Android targets,
# then packages everything into a flashable KernelSU module ZIP.
set -euo pipefail

VERSION=$(grep '^version' Cargo.toml | head -1 | sed 's/.*= *"\(.*\)"/\1/')
MODULE_ID="meta-overlayfsUltra"
OUTPUT_ZIP="target/${MODULE_ID}-v${VERSION}.zip"

echo "=== meta-overlayfsUltra build v${VERSION} ==="

# ---- Ensure Android cross-compilation targets are installed ----
rustup target add aarch64-linux-android x86_64-linux-android 2>/dev/null || true

# ---- Build for both architectures ----
echo "[1/3] Building aarch64..."
cargo build --release --target aarch64-linux-android

echo "[2/3] Building x86_64..."
cargo build --release --target x86_64-linux-android

# ---- Assemble the module ZIP ----
echo "[3/3] Packaging..."
STAGING=$(mktemp -d)
trap "rm -rf $STAGING" EXIT

# Copy metamodule files
cp -r metamodule/. "$STAGING/"

# Copy architecture-specific binaries
cp "target/aarch64-linux-android/release/${MODULE_ID}" \
   "$STAGING/${MODULE_ID}-aarch64"
cp "target/x86_64-linux-android/release/${MODULE_ID}" \
   "$STAGING/${MODULE_ID}-x86_64"

# Create placeholder for ext4 image (created at install time)
touch "$STAGING/.gitkeep"

# Create the ZIP
mkdir -p target
(cd "$STAGING" && zip -r9 - .) > "$OUTPUT_ZIP"

echo "=== Build complete: $OUTPUT_ZIP ==="
ls -lh "$OUTPUT_ZIP"
