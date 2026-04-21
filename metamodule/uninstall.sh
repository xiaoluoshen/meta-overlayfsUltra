#!/system/bin/sh
# meta-overlayfsUltra — 自身卸载脚本
# 在卸载 meta-overlayfsUltra 本身时调用，清理 ext4 镜像和挂载点。

MODDIR="${0%/*}"
MNT_DIR="$MODDIR/mnt"
IMG_FILE="$MODDIR/modules.img"

# 如果 ext4 镜像已挂载，先卸载
if mountpoint -q "$MNT_DIR" 2>/dev/null; then
    umount "$MNT_DIR" 2>/dev/null
fi

# 删除镜像文件和挂载点目录
rm -f "$IMG_FILE"
rmdir "$MNT_DIR" 2>/dev/null

# 删除元模块符号链接
rm -f /data/adb/metamodule
