# E5786 / Hi6930 Balong V7R2 TUN module research

Status: **source/toolchain not yet validated; no installable `tun.ko` is produced by this repository yet.**

This directory records the running E5786 kernel facts and provides a guarded GitHub Actions build path. The workflow is deliberately manual and does not load or install a module on a device.

## Confirmed from the user's E5786

| Item | Observed value |
|---|---|
| Device/platform | Huawei E5786, HiSilicon Hi6930 / Balong V7R2 |
| Kernel release | `3.4.5` |
| Build string | `#1 PREEMPT Tue Jun 7 19:28:29 CST 2016` |
| Build compiler string | `gcc version 4.6.x-google 20120106 (prerelease)` |
| Architecture | `armv7l` |
| `CONFIG_MODULES` | `y` |
| `CONFIG_TUN` | not set |
| `CONFIG_MODVERSIONS` | not set |
| `CONFIG_KALLSYMS` / `CONFIG_KALLSYMS_ALL` | `y` |
| `CONFIG_DEBUG_INFO` | `y` |
| `modules_disabled` | `0` |
| `/proc/kallsyms` | 51,574 lines in the captured check |

Existing module metadata reported by the user:

- `/system/bin/wifi_brcm/driver/dhd.ko`: `vermagic=3.4.5 preempt mod_unload ARMv7` (matches the running kernel's release string).
- `/system/bin/ctf.ko`: `vermagic=3.4.5+ preempt mod_unload ARMv7` (not an exact match).

The device has no `/usr/src`, `/lib/modules`, `/system/lib/modules`, `Module.symvers`, `System.map`, `vmlinux`, or existing `tun.ko` in the searched paths. The user observed several TUN-related kernel exports in `/proc/kallsyms`; that is encouraging but is not a complete module-link check.

No `tun` driver/device is currently present. A manually created `/dev/net/tun` node is not proof of kernel support.

## Source provenance and limitations

The community-maintained [Huawei Balong source index](https://github.com/Huawei-LTE-routers-mods/README/blob/master/balong_source_code.md) lists:

- Hi6930 / Balong V7R2: `E3372s-153 Open Source.part{1,2,3}.rar`.
- The index explicitly warns that Huawei's source archives are semi-broken/incomplete and may contain wrong configuration and structure definitions/offsets; it says that, to the maintainer's knowledge, nobody had built a working kernel from the provided archives.

The [Balong platform overview](https://github.com/Huawei-LTE-routers-mods/README/blob/master/balong_series.md) identifies E5786 as Hi6930 / V7R2.

A community [V7R2 development discussion](https://4pda.to/forum/index.php?showtopic=582284&st=560) has been reported to describe a TUN module that loaded but crashed when an interface was created. Treat this as a warning that successful `insmod` alone is not sufficient validation.

Do **not** substitute a V7R11 / Hi6921 / E3372h module. The E3372h community module project targets a different platform/configuration.

## Required inputs before building

The two device-captured files have now been added to this branch in compressed Base64 form to keep the repository text-only:

1. `kernel/e5786-v7r2/config/e5786-running.config.gz.b64` — gzip-compressed text from `/proc/config.gz`, Base64 encoded.
2. `kernel/e5786-v7r2/config/e5786-exported-symbols.txt.gz.b64` — gzip-compressed exported symbol names from `/proc/kallsyms`, Base64 encoded.

The workflow decodes both files, checks key configuration values and known exported symbols, then passes the restored files to the build script. These are the user's captured E5786 files, not values copied from a different Huawei model.

The workflow also requires two HTTPS archive URLs and SHA-256 digests supplied at dispatch:

- A **complete, extracted and re-packed tar archive** of the Hi6930 V7R2 kernel source (RAR multipart archives must be combined/extracted and repacked as .tar.gz or .tar.xz first).
- The ARM cross-toolchain archive containing the expected GCC 4.6 series compiler. The workflow checks `gcc -dumpversion` begins with `4.6`.

The source index notes that the public source may be incomplete. A build is only a candidate until the full source tree, generated headers, module imports, and runtime behavior are checked against this exact E5786.

## Build checks

The build script:

1. Checks kernel source version fields are Linux 3.4.5 and that `drivers/net/tun.c` exists.
2. Starts from the captured E5786 configuration and changes only `CONFIG_TUN` to `m` before running the 3.4.5 `oldconfig`/module preparation steps.
3. Builds `drivers/net/tun.ko` with an ARM cross compiler in the GCC 4.6 series.
4. Requires exact module vermagic: `3.4.5 preempt mod_unload ARMv7`.
5. Checks ELF architecture and compares unresolved module imports with the E5786 exported-symbol list.
6. Publishes the module and build report as a short-lived GitHub Actions artifact only.

The workflow does **not** patch Huawei-specific kernel structure layouts automatically, does not alter the source tree to guess at missing vendor changes, and does not load the resulting module. A matching vermagic and import list still do not prove runtime safety.

## Capture device facts

Run the included script on the E5786:

```sh
/system/bin/busybox sh /online/vpn/run/e5786-v7r2-probe.sh
```

Copy it there first using ADB:

```sh
adb push scripts/e5786-v7r2-probe.sh /online/vpn/run/e5786-v7r2-probe.sh
adb shell
/system/bin/busybox sh /online/vpn/run/e5786-v7r2-probe.sh
```

Then pull the captured files to the Mac:

```sh
adb pull /online/vpn/run/e5786-v7r2-probe/e5786-running.config .
adb pull /online/vpn/run/e5786-v7r2-probe/e5786-exported-symbols.txt .
```

The captures are already stored in `kernel/e5786-v7r2/config/` on this research branch. They contain kernel build metadata and exported symbol names, not VLESS credentials.

## Safety rule

**Do not load an artifact on the E5786 just because the workflow compiled it.** First inspect its vermagic, ELF header, imports, module layout, and source provenance. The first runtime test must be performed with a recovery path available and with no router-wide traffic redirect enabled.
