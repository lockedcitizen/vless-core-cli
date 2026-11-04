#!/usr/bin/env bash
set -euo pipefail

: "${KERNEL_SRC:?Set KERNEL_SRC to the extracted upstream Linux 3.4.5 tree}"
: "${CROSS_COMPILE:?Set CROSS_COMPILE to the ARM GCC 4.6.x prefix}"
: "${EXPORTS_FILE:?Set EXPORTS_FILE to the E5786 exported-symbol capture}"
OUT_DIR="${OUT_DIR:-$PWD/dist}"
EXPECTED_RELEASE="3.4.5"
EXPECTED_VERMAGIC="3.4.5 preempt mod_unload ARMv7"

[[ -f "$KERNEL_SRC/Makefile" && -f "$KERNEL_SRC/drivers/net/tun.c" ]] || {
  echo "Not a complete Linux kernel source tree: $KERNEL_SRC" >&2; exit 1;
}
[[ -s "$EXPORTS_FILE" ]] || { echo "Missing E5786 exports capture" >&2; exit 1; }
[[ -x "${CROSS_COMPILE}gcc" ]] || { echo "ARM GCC not found: ${CROSS_COMPILE}gcc" >&2; exit 1; }

kver=$(awk '$1=="VERSION" {v=$3} $1=="PATCHLEVEL" {p=$3} $1=="SUBLEVEL" {s=$3} END {print v"."p"."s}' "$KERNEL_SRC/Makefile")
[[ "$kver" == "$EXPECTED_RELEASE" ]] || { echo "Expected Linux $EXPECTED_RELEASE; found $kver" >&2; exit 1; }

gcc_version=$("${CROSS_COMPILE}gcc" -dumpversion)
case "$gcc_version" in 4.6*) ;; *) echo "Expected GCC 4.6.x, found $gcc_version" >&2; exit 1 ;; esac

mkdir -p "$OUT_DIR"

# Build an upstream ARMv7/VExpress configuration, not a Huawei platform config.
# This deliberately produces a generic comparison module, not an E5786-certified one.
make -C "$KERNEL_SRC" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" vexpress_defconfig
"$KERNEL_SRC/scripts/config" --file "$KERNEL_SRC/.config" \
  --enable MODULES \
  --enable MODULE_UNLOAD \
  --enable NET \
  --enable INET \
  --enable PREEMPT \
  --disable SMP \
  --disable MODVERSIONS \
  --disable LOCALVERSION_AUTO \
  --disable ARM_PATCH_PHYS_VIRT \
  --disable DEBUG_PREEMPT \
  --enable VMSPLIT_3G \
  --disable VMSPLIT_2G \
  --set-str LOCALVERSION "" \
  --module TUN

# Linux 3.4.5 oldconfig consumes blank answers as the Kconfig defaults.
make -C "$KERNEL_SRC" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" oldconfig </dev/null

for pair in \
  'CONFIG_MODULES=y' \
  'CONFIG_MODULE_UNLOAD=y' \
  'CONFIG_NET=y' \
  'CONFIG_INET=y' \
  'CONFIG_PREEMPT=y' \
  'CONFIG_VMSPLIT_3G=y' \
  'CONFIG_PAGE_OFFSET=0xC0000000' \
  'CONFIG_TUN=m'; do
  grep -qx "$pair" "$KERNEL_SRC/.config" || { echo "Required config missing after oldconfig: $pair" >&2; exit 1; }
done
grep -qx '# CONFIG_SMP is not set' "$KERNEL_SRC/.config" || {
  echo "Expected a UP build to mirror the E5786 vermagic shape" >&2; exit 1;
}
grep -qx '# CONFIG_ARM_PATCH_PHYS_VIRT is not set' "$KERNEL_SRC/.config" || {
  echo "Expected ARM_PATCH_PHYS_VIRT disabled to match the E5786 capture" >&2; exit 1;
}
grep -qx '# CONFIG_DEBUG_PREEMPT is not set' "$KERNEL_SRC/.config" || {
  echo "Expected DEBUG_PREEMPT disabled to match the E5786 capture" >&2; exit 1;
}
grep -qx '# CONFIG_VMSPLIT_2G is not set' "$KERNEL_SRC/.config" || {
  echo "Expected 2G virtual split disabled" >&2; exit 1;
}
grep -qx '# CONFIG_MODVERSIONS is not set' "$KERNEL_SRC/.config" || {
  echo "MODVERSIONS must remain disabled for this comparison build" >&2; exit 1;
}

make -C "$KERNEL_SRC" -j"$(getconf _NPROCESSORS_ONLN)" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" prepare modules_prepare
make -C "$KERNEL_SRC" -j"$(getconf _NPROCESSORS_ONLN)" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" M="$KERNEL_SRC/drivers/net" CONFIG_TUN=m modules

module="$KERNEL_SRC/drivers/net/tun.ko"
[[ -s "$module" ]] || { echo "Build did not produce drivers/net/tun.ko" >&2; exit 1; }
cp "$module" "$OUT_DIR/tun-generic-linux-3.4.5-armv7.ko"
cp "$KERNEL_SRC/.config" "$OUT_DIR/generic-vexpress.config"

# Verify basic file and ABI metadata. This is not a runtime-compatibility test.
readelf -h "$OUT_DIR/tun-generic-linux-3.4.5-armv7.ko" > "$OUT_DIR/elf-header.txt"
"${CROSS_COMPILE}nm" -u "$OUT_DIR/tun-generic-linux-3.4.5-armv7.ko" | awk 'NF {print $NF}' | sort -u > "$OUT_DIR/undefined-symbols.txt"
sort -u "$EXPORTS_FILE" > "$OUT_DIR/e5786-device-exports.txt"
comm -23 "$OUT_DIR/undefined-symbols.txt" "$OUT_DIR/e5786-device-exports.txt" > "$OUT_DIR/not-exported-by-e5786.txt"

vermagic=$(modinfo -F vermagic "$OUT_DIR/tun-generic-linux-3.4.5-armv7.ko" 2>/dev/null || true)
sha256sum "$OUT_DIR/tun-generic-linux-3.4.5-armv7.ko" > "$OUT_DIR/SHA256SUMS"
{
  echo "Build type: generic upstream Linux 3.4.5 ARMv7/VExpress comparison module"
  echo "Kernel source version: $kver"
  echo "Cross compiler: $("${CROSS_COMPILE}gcc" --version | head -n 1)"
  echo "Compiler dumpversion: $gcc_version"
  echo "Config: CONFIG_TUN=m; E5786-matched PREEMPT/VMSPLIT/ARM_PATCH_PHYS_VIRT/DEBUG_PREEMPT flags; CONFIG_SMP=n; CONFIG_MODVERSIONS=n"
  echo "Expected E5786 vermagic: $EXPECTED_VERMAGIC"
  echo "Actual module vermagic: ${vermagic:-unavailable}"
  echo "E5786 vermagic match: $([[ "$vermagic" == "$EXPECTED_VERMAGIC" ]] && echo yes || echo no)"
  echo "Undefined imports: $(wc -l < "$OUT_DIR/undefined-symbols.txt")"
  echo "Imports absent from E5786 export capture: $(wc -l < "$OUT_DIR/not-exported-by-e5786.txt")"
  echo
  echo "Build config uses the captured E5786 values for VMSPLIT_3G, PAGE_OFFSET, ARM_PATCH_PHYS_VIRT=n, and DEBUG_PREEMPT=n."
  echo "CRITICAL: This is still a generic upstream VExpress module. It was not built from the E5786 vendor source tree."
  echo "A vermagic match and export-name match do not validate vendor structure layouts or fastip/sk_buff ABI."
  echo "Do not insmod this module on the E5786. Runtime interface creation may crash the device."
} > "$OUT_DIR/build-report.txt"

printf '\n=== BUILD REPORT ===\n'
cat "$OUT_DIR/build-report.txt"
printf '\n=== SYMBOLS NOT FOUND IN E5786 EXPORT CAPTURE ===\n'
cat "$OUT_DIR/not-exported-by-e5786.txt"
