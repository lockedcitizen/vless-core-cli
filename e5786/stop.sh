#!/bin/sh
set -u
PIDDIR=${PIDDIR:-/online/vpn/run}
if [ -f "$PIDDIR/test-route" ]; then
  ip route del "$(cat "$PIDDIR/test-route")/32" via 10.77.0.1 dev tun0 2>/dev/null || true
  rm -f "$PIDDIR/test-route"
fi
for name in tun2socks core; do
  if [ -f "$PIDDIR/$name.pid" ]; then
    kill "$(cat "$PIDDIR/$name.pid")" 2>/dev/null || true
    rm -f "$PIDDIR/$name.pid"
  fi
done
ip link set tun0 down 2>/dev/null || true
echo "Stopped; default route was not changed."
