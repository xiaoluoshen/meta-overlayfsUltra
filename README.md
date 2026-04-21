# meta-overlayfsUltra

**极致隐藏 KernelSU 元模块** — 基于 OverlayFS 的高级无系统挂载实现，内置多层反检测加固。

> 这是一个 KernelSU [元模块](https://kernelsu.org/zh_CN/guide/metamodule.html)，用自研的加固版 OverlayFS 挂载逻辑替换 KernelSU 内置挂载机制，使所有模块挂载与原生 KernelSU 挂载完全无法区分。

---

## 功能特性

| 特性 | 说明 |
|---|---|
| **双目录架构** | 元数据（`/data/adb/modules/`）与内容（ext4 镜像挂载点）分离存储 |
| **现代 fsopen API** | Linux ≥ 5.2（GKI 内核）使用 `fsopen` / `fsmount` / `move_mount`；自动回退至传统 `mount(2)` |
| **挂载源 = "KSU"** | 所有 overlay 挂载的 `source` 字段强制设为 `KSU`，与原生 KernelSU 挂载完全一致 |
| **挂载命名空间隔离** | `unshare(CLONE_NEWNS)` 创建私有挂载命名空间，其他进程不可见 |
| **SELinux 上下文镜像** | `chcon --reference` 将原生分区上下文复制到所有挂载点 |
| **进程名伪装** | `prctl(PR_SET_NAME)` 将进程名改为内核线程名，规避进程列表扫描 |
| **无 journal ext4 镜像** | `mke2fs -O ^has_journal` 格式化，不产生 jbd2 sysfs 节点 |
| **稀疏文件复制** | 内置 `xcp` 子命令，迁移 ext4 镜像时保持稀疏特性 |
| **读写覆盖层** | 通过 `/data/adb/modules/.rw/` 支持 upperdir/workdir 实时系统编辑 |
| **时序抖动** | 挂载前随机延迟 ≤ 20ms，防止基于时序的启动检测 |

---

## 支持的分区

`system`、`vendor`、`product`、`system_ext`、`odm`、`oem`

---

## 安装方法

### 通过 KernelSU Manager 安装

1. 从 [Releases](../../releases) 下载最新的 `meta-overlayfsUltra-vX.Y.Z.zip`。
2. 打开 **KernelSU Manager → 模块 → +**。
3. 选择下载的 ZIP 文件。
4. 重启设备。

### 通过 ADB 安装

```shell
adb push meta-overlayfsUltra-v1.0.0.zip /sdcard/
adb shell su -c 'ksud module install /sdcard/meta-overlayfsUltra-v1.0.0.zip'
adb reboot
```

---

## 工作原理

```
post-fs-data 阶段
  └─ metamount.sh
       ├─ 挂载 modules.img（ext4 稀疏镜像）→ MODDIR/mnt/
       ├─ 为 .rw 目录应用 SELinux 上下文
       └─ 执行 meta-overlayfsUltra 二进制
            ├─ camouflage_process_name()   → prctl PR_SET_NAME 进程伪装
            ├─ timing_jitter_ms(20)        → 时序抖动反检测
            ├─ collect_enabled_modules()   → 扫描 /data/adb/modules/
            ├─ mount_partition("system")   → fsopen overlay，source=KSU
            └─ mount_partition(...)        → vendor / product / ...

service 阶段
  └─ service.sh
       └─ 镜像挂载点 SELinux 上下文，清理可疑痕迹
```

---

## 极致隐藏策略

| 策略 | 实现方式 | 防御效果 |
|---|---|---|
| **挂载源伪装** | `source=KSU`（必须项） | `/proc/mounts` 与原生 KernelSU 完全一致 |
| **命名空间隔离** | `unshare(CLONE_NEWNS)` | 检测 App 在其命名空间中看不到我们的挂载 |
| **SELinux 镜像** | `chcon --reference` | `ls -Z` 输出与未修改设备相同 |
| **进程名伪装** | `prctl(PR_SET_NAME)` → `kworker/u:0` | 进程列表无可疑条目 |
| **静默日志** | 生产环境不设置 `RUST_LOG` | logcat 无任何可疑输出 |
| **无 journal 镜像** | `mke2fs -O ^has_journal` | `/sys` 中不出现 jbd2 节点 |
| **时序抖动** | 随机延迟 ≤ 20ms | 防止基于启动时序的检测 |
| **fsopen 原子挂载** | `move_mount` 前不写入 `/proc/mounts` | 缩短可被检测的时间窗口 |

---

## 读写覆盖层

如需对系统分区进行持久化实时编辑：

```shell
mkdir -p /data/adb/modules/.rw/system/{upperdir,workdir}
```

upperdir 中的修改会持久保存在 ext4 镜像中，重启后依然有效。

---

## 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `MODULE_METADATA_DIR` | `/data/adb/modules/` | 存放 module.prop / disable / skip_mount 的目录 |
| `MODULE_CONTENT_DIR` | `/data/adb/metamodule/mnt/` | 存放模块内容树的目录（ext4 镜像挂载点） |
| `RUST_LOG` | （不设置） | 日志级别：`error`、`warn`、`info`、`debug` |

---

## 从源码构建

```shell
# 安装 Android 交叉编译目标
rustup target add aarch64-linux-android x86_64-linux-android

# 构建（需要 Android NDK）
./build.sh
# 输出：target/meta-overlayfsUltra-v1.0.0.zip
```

---

## 项目结构

```
meta-overlayfsUltra/
├── src/
│   ├── main.rs          — 程序入口，子命令分发
│   ├── defs.rs          — 常量与路径定义
│   ├── mount.rs         — OverlayFS 挂载引擎（fsopen + 传统 mount 回退）
│   ├── stealth.rs       — 反检测引擎（命名空间、SELinux、进程伪装、时序抖动）
│   └── xcp.rs           — 稀疏文件高效复制
├── metamodule/
│   ├── module.prop      — 元模块声明（metamodule=1）
│   ├── customize.sh     — 安装脚本（架构选择 + ext4 镜像创建）
│   ├── metamount.sh     — 挂载处理程序（KernelSU 调用）
│   ├── metainstall.sh   — 常规模块安装钩子
│   ├── metauninstall.sh — 常规模块卸载钩子
│   ├── post-mount.sh    — 挂载后 SELinux 上下文恢复
│   ├── service.sh       — 启动后隐藏强化
│   └── uninstall.sh     — 自身卸载清理
├── Cargo.toml
└── build.sh
```

---

## 许可证

GPL-3.0 — 详见 [LICENSE](LICENSE)
