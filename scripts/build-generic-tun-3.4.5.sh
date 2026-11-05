#!/bin/sh
set -eu

# This is a reference build only. It does not use Huawei's private/vendor
# kernel tree, generated headers, .config or Module.symvers.
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK="$ROOT/.build-tun-reference"
DIST="$ROOT/dist-e5786-tun-reference"
KERNEL_VERSION=3.4.5
KERNEL_ARCHIVE="$WORK/linux-$KERNEL_VERSION.tar.xz"
KERNEL_DIR="$WORK/linux-$KERNEL_VERSION"
CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabi-}"
JOBS="${JOBS:-2}"

command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1
command -v "${CROSS_COMPILE}readelf" >/dev/null 2>&1
command -v curl >/dev/null 2>&1
command -v make >/dev/null 2>&1
command -v xz >/dev/null 2>&1

rm -rf "$WORK" "$DIST"
mkdir -p "$WORK" "$DIST"

curl --fail --location --retry 3 \
  "https://cdn.kernel.org/pub/linux/kernel/v3.x/linux-$KERNEL_VERSION.tar.xz" \
  -o "$KERNEL_ARCHIVE"
tar -xJf "$KERNEL_ARCHIVE" -C "$WORK"

cd "$KERNEL_DIR"
make ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" vexpress_defconfig

# Enable loadable modules and TUN as a module. VExpress is an upstream
# ARMv7 reference configuration, not the Huawei Hi6930 board configuration.
scripts/config --enable MODULES
scripts/config --enable MODULE_UNLOAD
scripts/config --enable PREEMPT
scripts/config --disable MODVERSIONS
scripts/config --enable NET
scripts/config --enable INET
scripts/config --module TUN
scripts/config --set-str LOCALVERSION ""
scripts/config --disable LOCALVERSION_AUTO

make ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" oldconfig </dev/null
grep -q '^CONFIG_MODULES=y$' .config
grep -q '^CONFIG_TUN=m$' .config
grep -q '^# CONFIG_MODVERSIONS is not set$' .config

make -j"$JOBS" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" modules_prepare
make -j"$JOBS" ARCH=arm CROSS_COMPILE="$CROSS_COMPILE" drivers/net/tun.ko

test -s drivers/net/tun.ko
cp drivers/net/tun.ko "$DIST/tun.ko"
cp .config "$DIST/reference-kernel.config"
cp Module.symvers "$DIST/reference-Module.symvers" 2>/dev/null || true
"${CROSS_COMPILE}nm" -u "$DIST/tun.ko" > "$DIST/tun-undefined-symbols.txt"
modinfo "$DIST/tun.ko" > "$DIST/modinfo.txt"

cat > "$DIST/COMPATIBILITY.txt" <<EOF
STATUS: REFERENCE BUILD ONLY — NOT FOR INSTALLATION ON THE E5786

Source: upstream Linux $KERNEL_VERSION
Kernel configuration: upstream ARM VExpress reference configuration
Target architecture: ARMv7
Module: drivers/net/tun.c built as tun.ko

This build does NOT use the Huawei E5786 vendor kernel source tree, the
modem's generated kernel headers, its exact .config, its Module.symvers,
or its kernel build compiler. A matching kernel release string or vermagic
does not prove module ABI compatibility.

The modem previously rebooted when creating tun0 with ip tuntap. Do not
insmod this reference module and do not repeat that interface-creation test.
Obtain the exact Huawei kernel build tree and reproduce the vendor build
environment before producing an installable E5786 module.
EOF

cat > "$DIST/BUILD-INFO.txt" <<EOF
Kernel source: upstream Linux $KERNEL_VERSION
ARCH=arm
CROSS_COMPILE=$CROSS_COMPILE
Defconfig: vexpress_defconfig
CONFIG_TUN=m
CONFIG_MODULES=y
CONFIG_PREEMPT=y
CONFIG_MODVERSIONS=n
Classification: generic ARMv7 reference module; not Huawei E5786 compatible
EOF

"${CROSS_COMPILE}readelf" -h "$DIST/tun.ko" > "$DIST/elf-header.txt"
echo "Built reference module (DO NOT INSTALL ON E5786): $DIST/tun.ko"
