#!/usr/bin/env bash
set -euo pipefail

: "${KERNEL_SRC:?Set KERNEL_SRC to the extracted Linux 3.4.5 kernel tree}"
: "${KERNEL_CONFIG:?Set KERNEL_CONFIG to the captured E5786 .config}"
: "${EXPORTS_FILE:?Set EXPORTS_FILE to E5786 exported-symbol names}"
: "${CROSS_COMPILE:?Set CROSS_COMPILE, e.g. /opt/toolchain/bin/arm-eabi-}"

EXPECTED_RELEASE="${EXPECTED_RELEASE:-3.4.5}"
EXPECTED_VERMAGIC="${EXPECTED_VERMAGIC:-3.4.5 preempt mod_unload ARMv7}"
OUT_DIR="${OUT_DIR:-$PWD/dist}"

test -f "$KERNEL_SRC/Makefile"
test -f "$KERNEL_SRC/drivers/net/tun.c"
test -f "$KERNEL_SRC/drivers/net/Makefile"
test -f "$KERNEL_SRC/include/linux/module.h"
test -s "$KERNEL_CONFIG"
test -s "$EXPORTS_FILE"
test -x "${CROSS_COMPILE}gcc"
mkdir -p "$OUT_DIR"

version_value() {
    awk -F= -v key="$1" '$1 == key {gsub(/[[:space:]]/, "", $2); print $2}' "$KERNEL_SRC/Makefile"
}
KVER="$(version_value VERSION)"
KPATCH="$(version_value PATCHLEVEL)"
KSUB="$(version_value SUBLEVEL)"
if [[ "$KVER.$KPATCH.$KSUB" != "$EXPECTED_RELEASE" ]]; then
    echo "Refusing source version $KVER.$KPATCH.$KSUB; expected $EXPECTED_RELEASE" >&2
    exit 1
fi

GCC_VERSION="$("${CROSS_COMPILE}gcc" -dumpversion)"
case "$GCC_VERSION" in
    4.6*) ;;
    *)
        echo "Refusing GCC $GCC_VERSION; expected GCC 4.6.x for this target" >&2
        exit 1
        ;;
esac

echo "Compiler: $("${CROSS_COMPILE}gcc" --version | head -n 1)"
echo "Kernel source: $KERNEL_SRC"
echo "Kernel target: $EXPECTED_RELEASE"
echo "Compiler version: $GCC_VERSION"

cp "$KERNEL_CONFIG" "$KERNEL_SRC/.config"

python3 - "$KERNEL_SRC/.config" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
lines = p.read_text().splitlines()
lines = [
    line for line in lines
    if not line.startswith("CONFIG_TUN=")
    and line != "# CONFIG_TUN is not set"
]
lines.append("CONFIG_TUN=m")
p.write_text("\n".join(lines) + "\n")
PY

make -C "$KERNEL_SRC" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" oldconfig </dev/null
grep -qx 'CONFIG_TUN=m' "$KERNEL_SRC/.config" || {
    echo "CONFIG_TUN did not remain m after oldconfig; check kernel dependencies/config" >&2
    exit 1
}
grep -qx 'CONFIG_MODULES=y' "$KERNEL_SRC/.config" || {
    echo "Captured config does not enable modules" >&2
    exit 1
}
if grep -qx 'CONFIG_MODVERSIONS=y' "$KERNEL_SRC/.config"; then
    echo "Captured config unexpectedly enables MODVERSIONS; review symbol CRC handling" >&2
    exit 1
fi

make -C "$KERNEL_SRC" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" prepare modules_prepare
make -C "$KERNEL_SRC" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" M="$KERNEL_SRC/drivers/net" modules

MODULE="$KERNEL_SRC/drivers/net/tun.ko"
test -s "$MODULE"

VERMAGIC="$(modinfo -F vermagic "$MODULE")"
if [[ "$VERMAGIC" != "$EXPECTED_VERMAGIC" ]]; then
    echo "Vermagic mismatch: '$VERMAGIC' (expected '$EXPECTED_VERMAGIC')" >&2
    exit 1
fi

readelf -h "$MODULE" | grep -Eq 'Class:[[:space:]]+ELF32'
readelf -h "$MODULE" | grep -Eq 'Machine:[[:space:]]+ARM'

nm -u "$MODULE" | awk 'NF {print $NF}' | sort -u > "$OUT_DIR/undefined-symbols.txt"
sort -u "$EXPORTS_FILE" > "$OUT_DIR/device-exports.txt"
comm -23 "$OUT_DIR/undefined-symbols.txt" "$OUT_DIR/device-exports.txt" > "$OUT_DIR/unresolved-on-device.txt"

if [[ -s "$OUT_DIR/unresolved-on-device.txt" ]]; then
    echo "Module imports symbols not found in the captured E5786 export table:" >&2
    cat "$OUT_DIR/unresolved-on-device.txt" >&2
    exit 1
fi

cp "$MODULE" "$OUT_DIR/tun.ko"
{
    echo "E5786 Hi6930 / Balong V7R2 TUN module candidate"
    echo "Kernel release: $EXPECTED_RELEASE"
    echo "Vermagic: $VERMAGIC"
    echo "Compiler: $("${CROSS_COMPILE}gcc" -dumpversion)"
    echo "Config: CONFIG_TUN=m"
    echo "MODVERSIONS: disabled in captured config"
    echo "Runtime load/interface creation: NOT TESTED"
    echo "Source provenance/vendor structure compatibility: MUST BE REVIEWED"
    echo
    modinfo "$OUT_DIR/tun.ko"
} > "$OUT_DIR/build-report.txt"

sha256sum "$OUT_DIR/tun.ko" > "$OUT_DIR/SHA256SUMS"
echo "Candidate built and checks passed: $OUT_DIR/tun.ko"
