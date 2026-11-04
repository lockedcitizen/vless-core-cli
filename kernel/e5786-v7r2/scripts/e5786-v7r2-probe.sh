#!/system/bin/busybox sh
# Read-only E5786 Hi6930 / Balong V7R2 kernel probe.
# Output is written under /online/vpn/run; no settings are changed.

B=/system/bin/busybox
OUT=${1:-/online/vpn/run/e5786-v7r2-probe}

$B mkdir -p "$OUT" || exit 1

{
    echo "=== E5786 V7R2 TUN build probe ==="
    echo
    echo "=== uname ==="
    $B uname -a
    echo
    echo "=== /proc/version ==="
    $B cat /proc/version
    echo
    echo "=== kernel config ==="
    $B zcat /proc/config.gz 2>/dev/null | $B grep -E '^(CONFIG_(MODULES|MODVERSIONS|TUN|ARM|PREEMPT|KALLSYMS|KALLSYMS_ALL|DEBUG_INFO|INET)=|# CONFIG_(MODVERSIONS|TUN) is not set)'
    echo
    echo "=== modules_disabled ==="
    $B cat /proc/sys/kernel/modules_disabled 2>/dev/null
    echo
    echo "=== loaded modules ==="
    $B cat /proc/modules
    echo
    echo "=== TUN device ==="
    $B ls -l /dev/net/tun 2>&1
    echo
    echo "=== TUN module sysfs ==="
    $B ls -ld /sys/module/tun 2>&1
} > "$OUT/facts.txt"

if [ -r /proc/config.gz ]; then
    $B zcat /proc/config.gz > "$OUT/e5786-running.config" || exit 1
else
    echo "ERROR: /proc/config.gz is unavailable" > "$OUT/error.txt"
    exit 1
fi

if [ -r /proc/kallsyms ]; then
    $B grep '__ksymtab_' /proc/kallsyms \
        | $B sed 's/.*__ksymtab_//' \
        | $B sort -u > "$OUT/e5786-exported-symbols.txt"
else
    echo "ERROR: /proc/kallsyms is unavailable" > "$OUT/error.txt"
    exit 1
fi

echo "Probe files written to: $OUT"
$B ls -l "$OUT"
