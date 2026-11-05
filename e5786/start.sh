#!/bin/sh
set -eu
BASE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
URI_FILE=${URI_FILE:-/online/vpn/config/vless-uri.txt}
PIDDIR=${PIDDIR:-/online/vpn/run}
TUN_NAME=${TUN_NAME:-tun0}
mkdir -p "$PIDDIR"

[ -x "$BASE/vless-core-e5786-armv5" ] || { echo "Missing VLESS core binary" >&2; exit 1; }
[ -x "$BASE/tun2socks-e5786-armv5" ] || { echo "Missing tun2socks binary" >&2; exit 1; }
[ -r "$URI_FILE" ] || { echo "Missing private VLESS URI file: $URI_FILE" >&2; exit 1; }
[ -c /dev/net/tun ] || { echo "/dev/net/tun missing: load and validate the matching tun.ko first" >&2; exit 1; }

if [ -f "$PIDDIR/core.pid" ] && kill -0 "$(cat "$PIDDIR/core.pid")" 2>/dev/null; then
  echo "VLESS core already running"; exit 1
fi
if [ -f "$PIDDIR/tun2socks.pid" ] && kill -0 "$(cat "$PIDDIR/tun2socks.pid")" 2>/dev/null; then
  echo "tun2socks already running"; exit 1
fi

# Keep the URI out of argv. vless-core-cli reads fd 3 until EOF.
"$BASE/vless-core-e5786-armv5" --uri-fd 3 --listen-port 10808 3<"$URI_FILE" \
  >"$PIDDIR/core.log" 2>&1 &
echo $! > "$PIDDIR/core.pid"
sleep 2
if ! kill -0 "$(cat "$PIDDIR/core.pid")" 2>/dev/null; then
  echo "VLESS core failed; inspect $PIDDIR/core.log" >&2
  exit 1
fi

"$BASE/tun2socks-e5786-armv5" --logger stdout --loglevel notice \
  --tundev "$TUN_NAME" --netif-ipaddr 10.77.0.1 \
  --netif-netmask 255.255.255.0 --socks-server-addr 127.0.0.1:10808 \
  >"$PIDDIR/tun2socks.log" 2>&1 &
echo $! > "$PIDDIR/tun2socks.pid"
sleep 2
if ! kill -0 "$(cat "$PIDDIR/tun2socks.pid")" 2>/dev/null; then
  echo "tun2socks failed; inspect $PIDDIR/tun2socks.log" >&2
  kill "$(cat "$PIDDIR/core.pid")" 2>/dev/null || true
  exit 1
fi

ip link set "$TUN_NAME" up
ip addr add 10.77.0.2/24 dev "$TUN_NAME" 2>/dev/null || true
echo "VLESS + TUN bridge started. Default route was NOT changed."
echo "Use ./route-test.sh <IPv4-address> for one TCP smoke test."
