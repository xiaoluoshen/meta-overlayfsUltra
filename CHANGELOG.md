# 更新日志

## v1.0.0（2026-04-20）

### 首次发布

本版本为 meta-overlayfsUltra 的初始正式发布，基于 KernelSU 元模块规范构建，在官方参考实现 meta-overlayfs 的基础上进行了全面的隐藏加固。

**核心架构**

采用双目录架构，元数据目录（`/data/adb/modules/`）与内容目录（ext4 稀疏镜像挂载点）完全分离，启动期间扫描速度更快，存储占用更小。

**挂载引擎**

优先使用现代 `fsopen(2)` / `fsmount(2)` / `move_mount(2)` API（Linux ≥ 5.2），在旧内核上自动回退至传统 `mount(2)` 系统调用。所有 overlay 挂载的 `source` 字段强制设为 `"KSU"`，与原生 KernelSU 挂载完全一致。

**反检测加固**

- 挂载命名空间隔离：`unshare(CLONE_NEWNS)` 创建私有挂载命名空间
- SELinux 上下文镜像：`chcon --reference` 复制原生分区上下文
- 进程名伪装：`prctl(PR_SET_NAME)` 将进程名改为 `kworker/u:0`
- 无 journal ext4 镜像：`mke2fs -O ^has_journal` 格式化，不产生 jbd2 sysfs 节点
- 时序抖动：挂载前随机延迟 ≤ 20ms
- 静默日志：生产环境不向 logcat 输出任何信息

**其他特性**

- 内置 `xcp` 子命令：稀疏文件高效复制，迁移 ext4 镜像时不膨胀稀疏区域
- 读写覆盖层：通过 `/data/adb/modules/.rw/` 支持 upperdir/workdir
- 支持分区：system、vendor、product、system_ext、odm、oem
- GitHub Actions CI/CD：推送 tag 自动构建并发布 Release
