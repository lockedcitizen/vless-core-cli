#!/bin/sh
set -eu
[ "$#" -eq 1 ] || { echo "Usage: $0 destination-ipv4" >&2; exit 2; }
case "$1" in *[!0-9.]*|'') echo "IPv4 literal required" >&2; exit 2;; esac
PIDDIR=${PIDDIR:-/online/vpn/run}
mkdir -p "$PIDDIR"
[ ! -f "$PIDDIR/test-route" ] || ip route del "$(cat "$PIDDIR/test-route")/32" via 10.77.0.1 dev tun0 2>/dev/null || true
ip route add "$1/32" via 10.77.0.1 dev tun0
printf '%s' "$1" > "$PIDDIR/test-route"
echo "Added route for $1 through tun0. This TCP-only build will not proxy UDP."
