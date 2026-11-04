#!/usr/bin/env python3
"""Apply the small-RAM, TCP-only E5786 profile to pinned BadVPN sources."""
from pathlib import Path
import sys

root = Path(sys.argv[1])

opts = root / "lwip/custom/lwipopts.h"
s = opts.read_text()
replacements = {
    "#define MEMP_NUM_TCP_PCB_LISTEN 16": "#define MEMP_NUM_TCP_PCB_LISTEN 1",
    "#define MEMP_NUM_TCP_PCB 1024": "#define MEMP_NUM_TCP_PCB 8",
    "#define TCP_MSS 1460": "#define TCP_MSS 1360\n#define TCP_WND 4096",
    "#define TCP_SND_BUF 16384": "#define TCP_SND_BUF 4096",
    "#define TCP_SND_QUEUELEN (4 * (TCP_SND_BUF)/(TCP_MSS))":
        "#define TCP_SND_QUEUELEN 8\n#define TCP_QUEUE_OOSEQ 0",
}
for old, new in replacements.items():
    if old not in s:
        raise SystemExit("BadVPN lwIP option not found: " + old)
    s = s.replace(old, new, 1)
opts.write_text(s)

tun = root / "tun2socks/tun2socks.c"
s = tun.read_text()
needle = "err_t listener_accept_func (void *arg, struct tcp_pcb *newpcb, err_t err)\n{\n    ASSERT(err == ERR_OK)"
replacement = (
    "err_t listener_accept_func (void *arg, struct tcp_pcb *newpcb, err_t err)\n{\n"
    "    ASSERT(err == ERR_OK)\n"
    "    if (num_clients >= 4) {\n"
    '        BLog(BLOG_WARNING, "E5786 TCP flow limit reached; rejecting flow");\n'
    "        tcp_abort(newpcb);\n"
    "        return ERR_ABRT;\n"
    "    }"
)
if needle not in s:
    raise SystemExit("BadVPN TCP accept handler not found")
tun.write_text(s.replace(needle, replacement, 1))
