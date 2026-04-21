#!/system/bin/sh
# meta-overlayfsUltra — 模块安装钩子
# 由 KernelSU 内置安装程序在安装常规模块时 source 执行。
# 在文件解压后、安装完成前调用。
# 注意：安装 meta-overlayfsUltra 自身时不会调用此脚本。

# 检查 KernelSU 版本兼容性
if [ -n "$KSU_VER_CODE" ] && [ "$KSU_VER_CODE" -lt 10940 ]; then
    ui_print "! 警告：当前 KernelSU 版本可能不完全支持元模块功能"
fi

# 执行标准安装流程
install_module

ui_print "- meta-overlayfsUltra：模块已通过极致隐藏处理程序安装"
