# Changelog

## v1.0.0 (2026-04-20)

### Initial Release

- Dual-directory architecture: metadata in `/data/adb/modules/`, content in ext4 image
- Modern `fsopen(2)` / `fsmount(2)` / `move_mount(2)` API with legacy `mount(2)` fallback
- Source identifier always set to `"KSU"` for mount camouflage
- Mount-namespace isolation via `unshare(CLONE_NEWNS)`
- SELinux context mirroring with `chcon --reference`
- Process name camouflage via `prctl(PR_SET_NAME)`
- Journal-free ext4 image (no jbd2 sysfs node)
- Sparse-aware `xcp` sub-command for image migration
- Read-write overlay support via `/data/adb/modules/.rw/`
- Supported partitions: system, vendor, product, system_ext, odm, oem
- Timing jitter (≤ 20 ms) for anti-timing detection
