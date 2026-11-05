#!/usr/bin/env python3
"""Apply small-RAM limits to vless-core-cli and pinned BadVPN tun2socks."""
from pathlib import Path
import sys

if len(sys.argv) != 3:
    raise SystemExit("usage: patch-badvpn-e5786.py CORE_REPO BADVPN_SOURCE")
core = Path(sys.argv[1])
root = Path(sys.argv[2])

# Keep the upstream default unchanged for ordinary builds; the E5786 build
# overrides the limit to four concurrent client connections.
main = core / "src/main.c"
s = main.read_text()
old = "#define MAX_CLIENT_CONNECTIONS 256"
new = "#ifndef MAX_CLIENT_CONNECTIONS\n#define MAX_CLIENT_CONNECTIONS 256\n#endif"
if old in s:
    main.write_text(s.replace(old, new, 1))
elif new not in s:
    raise SystemExit("vless-core MAX_CLIENT_CONNECTIONS definition not found")

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
        if new not in s:
            raise SystemExit("BadVPN lwIP option not found: " + old)
    else:
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
if needle in s:
    tun.write_text(s.replace(needle, replacement, 1))
elif "num_clients >= 4" not in s:
    raise SystemExit("BadVPN TCP accept handler not found")
