#!/system/bin/sh
# meta-overlayfsUltra — 服务脚本
# 在 late_start service 阶段执行，进行启动后隐藏加固。

MODDIR="${0%/*}"

# ---- 为 ext4 镜像挂载点应用原生 SELinux 上下文 ----
# 使文件扫描器无法通过上下文差异检测到挂载点
MNT_DIR="$MODDIR/mnt"
if mountpoint -q "$MNT_DIR" 2>/dev/null; then
    chcon u:object_r:system_file:s0 "$MNT_DIR" 2>/dev/null
fi

# ---- 清理二进制文件的可疑扩展属性 ----
setfattr -x security.selinux "$MODDIR/meta-overlayfsUltra" 2>/dev/null || true
chcon u:object_r:system_file:s0 "$MODDIR/meta-overlayfsUltra" 2>/dev/null

# 无需常驻守护进程
