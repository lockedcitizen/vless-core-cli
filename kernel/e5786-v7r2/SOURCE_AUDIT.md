# E5786 V7R2 source availability and compatibility audit

Status: **No verified, complete, E5786-matching source tree has been obtained. Do not build or load a candidate from a substitute tree.**

## Candidate named in the public Huawei source index

The Huawei Balong source index lists `E3372s-153 Open Source.part{1,2,3}.rar` under Hi6930 / Balong V7R2. It also warns that the vendor archives can be incomplete and that configurations and structure definitions may be wrong.

Reference:
- https://github.com/Huawei-LTE-routers-mods/README/blob/master/balong_source_code.md

## Compatibility concerns reported by the community

A detailed 4PDA discussion of the same Hi6930 V7R2 source effort reports that:

- The supplied source archive did not contain the expected `hi6930_v7r2_hilink` / `hi6930_v7r2_stick` product configuration directories.
- Its kernel configuration differed substantially from the configuration extracted from a running device.
- The resulting source-built `vmlinux` was reported as about 82 MB, compared with about 112 MB for the delivered E5786 kernel image, and was said to lack modem-specific code.
- A TUN module experiment was reported to load but then crash when creating a TUN/TAP interface.

Reference (discussion in Russian; browser translation may help):
- https://4pda.to/forum/index.php?showtopic=582284&st=560
- https://4pda.to/forum/index.php?showtopic=582284&st=520

These are community reports, not independent reproduction, but they are sufficiently relevant to block treating the archive or a successful `insmod` as proof of compatibility.

## Other public repositories rejected as direct build sources

- `im-0/e3372h-kmods` is explicitly an E3372h / Hi6921 V7R11 project. Although its shared kernel tree contains some Hi6930 V7R2 support files, its product configuration and captured kernel config are V7R11-oriented. It must not be used as an E5786 build source without a source-level audit and validation.
  - https://github.com/im-0/e3372h-kmods
- `hisili/E5573Cs` identifies itself as E5573Cs-322 and its product metadata reports `hi6921_v711` / `V700R110C30B327`. The fact that its shared kernel tree contains `ARCH_V7R2` code does not make that repository an E5786 V7R2 source tree.
  - https://github.com/hisili/E5573Cs

## Required next source route

The Huawei Open Source Release Center says that users who cannot find the matching source should contact `mobile@huawei.com` with the subject **Open Source Codes Issue**. It notes that Huawei may charge the physical distribution cost if a CD is requested.

Reference:
- https://consumer.huawei.com/en/opensource/

Request specifically:
- Product: Huawei E5786
- Platform: HiSilicon Hi6930 / Balong V7R2
- Firmware: `21.313.17.00.00.mod1.2`
- Kernel: Linux `3.4.5`
- Matching kernel tree, product configuration, generated headers, and the ARM GCC 4.6.x toolchain/build metadata

## Device captures already committed

The exact E5786 captures remain:
- `config/e5786-running.config`
- `config/e5786-exported-symbols.txt`

They show `CONFIG_ARCH_HI6930=y`, `CONFIG_ARCH_V7R2=y`, `CONFIG_MODULES=y`, `# CONFIG_TUN is not set`, and `# CONFIG_MODVERSIONS is not set`.

## Decision

Do not substitute V7R11 source or a generic Linux 3.4.5 source tree. Do not run `insmod` on a candidate solely because it compiles or has matching vermagic. Wait for a source tree and toolchain whose relationship to the E5786 firmware can be demonstrated, then validate all imports and the device-specific structure layout before any isolated runtime test.
