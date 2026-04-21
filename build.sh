#!/usr/bin/env bash
# meta-overlayfsUltra — 构建脚本
# 为 aarch64 和 x86_64 Android 目标编译 Release 二进制，
# 并将所有文件打包为可刷入的 KernelSU 模块 ZIP。
set -euo pipefail

VERSION=$(grep '^version' Cargo.toml | head -1 | sed 's/.*= *"\(.*\)"/\1/')
MODULE_ID="meta-overlayfsUltra"
OUTPUT_ZIP="target/${MODULE_ID}-v${VERSION}.zip"

echo "=== meta-overlayfsUltra 构建 v${VERSION} ==="

# ---- 确保已安装 Android 交叉编译目标 ----
rustup target add aarch64-linux-android x86_64-linux-android 2>/dev/null || true

# ---- 编译两种架构 ----
echo "[1/3] 编译 aarch64..."
cargo build --release --target aarch64-linux-android

echo "[2/3] 编译 x86_64..."
cargo build --release --target x86_64-linux-android

# ---- 打包模块 ZIP ----
echo "[3/3] 打包中..."
STAGING=$(mktemp -d)
trap "rm -rf $STAGING" EXIT

# 复制元模块文件
cp -r metamodule/. "$STAGING/"

# 复制各架构二进制
cp "target/aarch64-linux-android/release/${MODULE_ID}" \
   "$STAGING/${MODULE_ID}-aarch64"
cp "target/x86_64-linux-android/release/${MODULE_ID}" \
   "$STAGING/${MODULE_ID}-x86_64"

# ext4 镜像在安装时创建，此处仅占位
touch "$STAGING/.gitkeep"

# 生成 ZIP
mkdir -p target
(cd "$STAGING" && zip -r9 - .) > "$OUTPUT_ZIP"

echo "=== 构建完成：$OUTPUT_ZIP ==="
ls -lh "$OUTPUT_ZIP"
