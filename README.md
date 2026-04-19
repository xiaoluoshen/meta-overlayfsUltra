# meta-overlayfsUltra

**Ultra-stealth KernelSU MetaModule** — advanced systemless overlay mounting with anti-detection hardening.

> A KernelSU [MetaModule](https://kernelsu.org/zh_CN/guide/metamodule.html) that replaces the built-in mount logic with a hardened OverlayFS implementation designed to be indistinguishable from stock KernelSU mounts.

---

## Features

| Feature | Description |
|---|---|
| **Dual-directory architecture** | Metadata (`/data/adb/modules/`) and content (`/data/adb/metamodule/mnt/`) are separated, stored in a sparse ext4 image |
| **Modern fsopen(2) API** | Uses `fsopen` / `fsmount` / `move_mount` on Linux ≥ 5.2; falls back to legacy `mount(2)` automatically |
| **Source = "KSU"** | All overlay mounts report `source=KSU` — identical to stock KernelSU, invisible to third-party detectors |
| **Mount-namespace isolation** | `unshare(CLONE_NEWNS)` creates a private namespace; mounts are invisible to processes outside the namespace |
| **SELinux context mirroring** | `chcon --reference` copies the stock partition context to all overlay mount points |
| **Process name camouflage** | `prctl(PR_SET_NAME)` renames the process to a benign kernel thread name |
| **Journal-free ext4 image** | `mke2fs -O ^has_journal` prevents a jbd2 sysfs node from appearing in `/sys` |
| **Sparse file copy** | Built-in `xcp` sub-command copies ext4 images without inflating sparse regions |
| **Read-write overlay** | Optional upperdir/workdir via `/data/adb/modules/.rw/` for live system edits |

---

## Supported Partitions

`system`, `vendor`, `product`, `system_ext`, `odm`, `oem`

---

## Installation

### Via KernelSU Manager

1. Download the latest `meta-overlayfsUltra-vX.Y.Z.zip` from [Releases](../../releases).
2. Open **KernelSU Manager → Modules → +**.
3. Select the ZIP file.
4. Reboot.

### Via ADB

```shell
adb push meta-overlayfsUltra-v1.0.0.zip /sdcard/
adb shell su -c 'ksud module install /sdcard/meta-overlayfsUltra-v1.0.0.zip'
adb reboot
```

---

## How It Works

```
post-fs-data phase
  └─ metamount.sh
       ├─ Mount modules.img (ext4, sparse) → MODDIR/mnt/
       ├─ Apply SELinux contexts to .rw dirs
       └─ Execute meta-overlayfsUltra binary
            ├─ camouflage_process_name()   → prctl PR_SET_NAME
            ├─ timing_jitter_ms(20)        → anti-timing detection
            ├─ collect_enabled_modules()   → scan /data/adb/modules/
            ├─ mount_partition("system")   → fsopen overlay, source=KSU
            └─ mount_partition(...)        → vendor / product / ...

service phase
  └─ service.sh
       └─ Mirror SELinux contexts on mount points
```

---

## Read-Write Overlay

To enable live system edits (e.g. for testing):

```shell
mkdir -p /data/adb/modules/.rw/system/{upperdir,workdir}
```

The upperdir will persist across reboots inside the ext4 image.

---

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `MODULE_METADATA_DIR` | `/data/adb/modules/` | Directory containing module.prop / disable / skip_mount |
| `MODULE_CONTENT_DIR` | `/data/adb/metamodule/mnt/` | Directory containing module content trees |
| `RUST_LOG` | *(unset)* | Log level: `error`, `warn`, `info`, `debug` |

---

## Building from Source

```shell
# Install Android NDK and add Rust targets
rustup target add aarch64-linux-android x86_64-linux-android

# Build
./build.sh
# Output: target/meta-overlayfsUltra-v1.0.0.zip
```

---

## Architecture

```
meta-overlayfsUltra/
├── src/
│   ├── main.rs       — entry point, sub-command dispatch
│   ├── defs.rs       — constants and path definitions
│   ├── mount.rs      — overlayfs mount engine (fsopen + legacy fallback)
│   ├── stealth.rs    — anti-detection: namespace, SELinux, process name
│   └── xcp.rs        — sparse-aware file copy
├── metamodule/
│   ├── module.prop   — metamodule=1 declaration
│   ├── customize.sh  — installation: arch selection + ext4 image creation
│   ├── metamount.sh  — mount handler (called by KernelSU)
│   ├── metainstall.sh— regular module install hook
│   ├── metauninstall.sh — regular module uninstall hook
│   ├── post-mount.sh — post-mount SELinux context restoration
│   ├── service.sh    — late_start stealth hardening
│   └── uninstall.sh  — self-uninstall cleanup
├── Cargo.toml
└── build.sh
```

---

## License

GPL-3.0 — see [LICENSE](LICENSE)
