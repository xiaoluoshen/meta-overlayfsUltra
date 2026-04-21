#!/system/bin/sh
# meta-overlayfsUltra — 挂载后处理脚本
# 在所有覆盖层应用完毕后执行。
# 恢复各挂载点的 SELinux 上下文，使 `ls -Z` 输出与未修改设备完全一致。

PARTITIONS="system vendor product system_ext odm oem"

for part in $PARTITIONS; do
    TARGET="/$part"
    if mountpoint -q "$TARGET" 2>/dev/null; then
        # 后台递归恢复 SELinux 上下文（静默执行，最大努力）
        restorecon -RF "$TARGET" 2>/dev/null &
    fi
done

# 等待所有后台 restorecon 任务完成（最多 5 秒）
wait
