#!/system/bin/sh
# meta-overlayfsUltra — 模块卸载钩子
# 在卸载常规模块时调用，负责清理该模块在 ext4 镜像中的内容目录。

MODULE_ID="$1"
MODDIR="${0%/*}"
MNT_DIR="$MODDIR/mnt"

if [ -z "$MODULE_ID" ]; then
    exit 0
fi

# 从已挂载的 ext4 镜像中删除该模块的内容目录
if [ -d "$MNT_DIR/$MODULE_ID" ]; then
    rm -rf "$MNT_DIR/$MODULE_ID"
fi
