#!/system/bin/sh
# meta-overlayfsUltra — 模块挂载处理程序
# 由 KernelSU 在 post-fs-data 阶段（第 6 步）调用。
# 执行双目录无系统挂载，并进行隐藏加固。

MODDIR="${0%/*}"
IMG_FILE="$MODDIR/modules.img"
MNT_DIR="$MODDIR/mnt"
RW_ROOT="/data/adb/modules/.rw"
PARTITIONS="system vendor product system_ext odm oem"
BINARY="$MODDIR/meta-overlayfsUltra"

# ---- 最小化日志（仅写入 kmsg，不写入 /sdcard）----
# 前缀使用通用名称，避免被日志扫描器检测
log() {
    echo "[ksu_mount] $1" 2>/dev/null
}

# ---- 确保 ext4 镜像已挂载 ----
if ! mountpoint -q "$MNT_DIR" 2>/dev/null; then
    if [ ! -f "$IMG_FILE" ]; then
        log "错误：镜像文件不存在"
        exit 1
    fi
    mkdir -p "$MNT_DIR"
    # 挂载前应用与原生文件相同的 SELinux 上下文
    chcon u:object_r:ksu_file:s0 "$IMG_FILE" 2>/dev/null
    mount -t ext4 -o loop,rw,noatime "$IMG_FILE" "$MNT_DIR" || {
        log "错误：ext4 挂载失败"
        exit 1
    }
fi

# ---- 验证二进制文件存在 ----
if [ ! -f "$BINARY" ]; then
    log "错误：二进制文件不存在"
    exit 1
fi

# ---- 为 .rw 覆盖层目录应用 SELinux 上下文 ----
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

# ---- 导出双目录路径供 Rust 二进制使用 ----
export MODULE_METADATA_DIR="/data/adb/modules"
export MODULE_CONTENT_DIR="$MNT_DIR"

# ---- 执行挂载二进制 ----
# 生产环境不设置 RUST_LOG，完全静默
"$BINARY"
EXIT_CODE=$?

[ $EXIT_CODE -ne 0 ] && log "错误：挂载二进制退出码 $EXIT_CODE"
exit $EXIT_CODE
