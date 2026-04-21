#!/system/bin/sh
# meta-overlayfsUltra — 安装脚本
# 根据设备架构选择对应二进制，并创建 ext4 稀疏镜像。

ui_print "- meta-overlayfsUltra 安装程序"
ui_print "- 正在检测设备架构..."

ABI=$(grep_get_prop ro.product.cpu.abi)
ui_print "- 检测到 ABI：$ABI"

case "$ABI" in
    arm64-v8a)
        ARCH_BINARY="meta-overlayfsUltra-aarch64"
        REMOVE_BINARY="meta-overlayfsUltra-x86_64"
        ui_print "- 架构：ARM64"
        ;;
    x86_64)
        ARCH_BINARY="meta-overlayfsUltra-x86_64"
        REMOVE_BINARY="meta-overlayfsUltra-aarch64"
        ui_print "- 架构：x86_64"
        ;;
    *)
        abort "! 不支持的架构：$ABI"
        ;;
esac

if [ ! -f "$MODPATH/$ARCH_BINARY" ]; then
    abort "! 二进制文件不存在：$ARCH_BINARY"
fi

mv "$MODPATH/$ARCH_BINARY" "$MODPATH/meta-overlayfsUltra" || abort "! 重命名二进制失败"
rm -f "$MODPATH/$REMOVE_BINARY"
chmod 755 "$MODPATH/meta-overlayfsUltra" || abort "! 设置权限失败"
ui_print "- 二进制文件安装完成"

# ---- 创建或复用 ext4 镜像 ----
IMG_FILE="$MODPATH/modules.img"
IMG_SIZE_MB=2048
EXISTING_IMG="/data/adb/modules/$MODID/modules.img"

if [ -f "$EXISTING_IMG" ]; then
    ui_print "- 检测到已有模块镜像，正在复用..."
    "$MODPATH/meta-overlayfsUltra" xcp "$EXISTING_IMG" "$IMG_FILE" || \
        abort "! 复制已有镜像失败"
else
    ui_print "- 正在创建 ${IMG_SIZE_MB}MB ext4 稀疏镜像..."
    truncate -s ${IMG_SIZE_MB}M "$IMG_FILE" || abort "! 创建镜像文件失败"
    # 不带 journal 格式化，避免在 /sys 中产生 jbd2 节点（隐藏加固）
    /system/bin/mke2fs -t ext4 -O ^has_journal -F "$IMG_FILE" >/dev/null 2>&1 || \
        abort "! 格式化 ext4 镜像失败"
    ui_print "- 镜像创建完成"
fi

# 为镜像文件应用正确的 SELinux 上下文
chcon u:object_r:ksu_file:s0 "$IMG_FILE" 2>/dev/null

ui_print "- 安装完成"
ui_print "- 请重启设备以激活 meta-overlayfsUltra"
