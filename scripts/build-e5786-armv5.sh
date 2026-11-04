#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
WORK="$ROOT/.build-e5786"
DIST="$ROOT/dist-e5786"
CROSS_COMPILE="${CROSS_COMPILE:-arm-linux-gnueabi-}"
CC="${CROSS_COMPILE}gcc"
STRIP="${CROSS_COMPILE}strip"
OPENSSL_VERSION=3.5.7
BADVPN_COMMIT=07268f02706e78e282e19641b5d1d41e8e89bf31
OPENSSL_PREFIX="$WORK/openssl-armv5"
JOBS="${JOBS:-2}"
CFLAGS="-Os -march=armv5te -mtune=arm926ej-s -mfloat-abi=soft -fno-strict-aliasing -ffunction-sections -fdata-sections"
LDFLAGS="-static -Wl,--gc-sections"

command -v "$CC" >/dev/null 2>&1 || { echo "Missing $CC" >&2; exit 1; }
command -v make >/dev/null 2>&1
command -v curl >/dev/null 2>&1
command -v python3 >/dev/null 2>&1
mkdir -p "$WORK" "$DIST"

fetch() {
  url=$1
  output=$2
  curl --fail --location --retry 3 --retry-all-errors "$url" -o "$output"
}

# Build a static, soft-float ARMv5TE OpenSSL for the modem's old userspace.
OPENSSL_TARBALL="$WORK/openssl-$OPENSSL_VERSION.tar.gz"
if [ ! -f "$OPENSSL_PREFIX/lib/libcrypto.a" ] || [ ! -f "$OPENSSL_PREFIX/lib/libssl.a" ]; then
  [ -f "$OPENSSL_TARBALL" ] || fetch "https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz" "$OPENSSL_TARBALL"
  rm -rf "$WORK/openssl-$OPENSSL_VERSION"
  tar -xzf "$OPENSSL_TARBALL" -C "$WORK"
  (
    cd "$WORK/openssl-$OPENSSL_VERSION"
    CROSS_COMPILE="$CROSS_COMPILE" CFLAGS="$CFLAGS" \
      ./Configure linux-armv4 no-shared no-asm no-tests no-apps \
      --cross-compile-prefix="$CROSS_COMPILE" --prefix="$OPENSSL_PREFIX"
    make -j"$JOBS"
    make install_sw
  )
fi

# Build VLESS core from this repository's checked-out source.
CORE_OBJ="$WORK/core-obj"
rm -rf "$CORE_OBJ"
mkdir -p "$CORE_OBJ"
for source in "$ROOT"/src/*.c; do
  object=$(basename "$source" .c)
  "$CC" $CFLAGS -std=c11 -D_GNU_SOURCE -DMAX_CLIENT_CONNECTIONS=4 \
    -DVLESS_CORE_COMMIT='"e5786-armv5te"' \
    -DVLESS_OPENSSL_PATCH_STATUS='"unpatched"' \
    -I"$ROOT/include" -I"$OPENSSL_PREFIX/include" \
    -c "$source" -o "$CORE_OBJ/$object.o"
done
"$CC" $LDFLAGS -o "$DIST/vless-core-e5786-armv5" "$CORE_OBJ"/*.o \
  "$OPENSSL_PREFIX/lib/libssl.a" "$OPENSSL_PREFIX/lib/libcrypto.a" -pthread -ldl
"$STRIP" "$DIST/vless-core-e5786-armv5"

# Fetch pinned BadVPN tun2socks/lwIP source.
BADVPN_TARBALL="$WORK/badvpn-$BADVPN_COMMIT.tar.gz"
[ -f "$BADVPN_TARBALL" ] || fetch \
  "https://codeload.github.com/ambrop72/badvpn/tar.gz/$BADVPN_COMMIT" "$BADVPN_TARBALL"
rm -rf "$WORK/badvpn"
mkdir -p "$WORK/badvpn"
tar -xzf "$BADVPN_TARBALL" --strip-components=1 -C "$WORK/badvpn"
python3 "$ROOT/scripts/patch-badvpn-e5786.py" "$WORK/badvpn"

# compile-tun2socks.sh builds the TUN packet reader + lwIP TCP stack + SOCKS5 bridge.
(
  cd "$WORK"
  SRCDIR="$WORK/badvpn" OUTDIR="$DIST" CC="$CC" \
    CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" ENDIAN=little KERNEL=2.6 \
    bash "$WORK/badvpn/compile-tun2socks.sh"
  mv "$DIST/tun2socks" "$DIST/tun2socks-e5786-armv5"
)
"$STRIP" "$DIST/tun2socks-e5786-armv5"

cp "$ROOT/e5786/start.sh" "$ROOT/e5786/stop.sh" "$ROOT/e5786/route-test.sh" "$DIST/"
cp "$ROOT/e5786/README.md" "$ROOT/e5786/BADVPN-BSD-3-CLAUSE.txt" "$DIST/"
cp "$ROOT/THIRD_PARTY_LICENSES.txt" "$DIST/" 2>/dev/null || true
cat > "$DIST/BUILD-INFO.txt" <<EOF
Target: ARMv5TE, ARM EABI, soft-float
Compiler: $CC
Flags: $CFLAGS
VLESS core connection cap: 4
tun2socks TCP flow cap: 4
TUN module: supplied separately; not built by this workflow
UDP/DNS/IPv6 forwarding: disabled/not supported in this first build
EOF

echo "Built artifacts:"
file "$DIST/vless-core-e5786-armv5" "$DIST/tun2socks-e5786-armv5"
