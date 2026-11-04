# Captured E5786 kernel build inputs

Commit these two files to the `research/e5786-v7r2-tun` branch before starting the build workflow:

- `e5786-running.config`: uncompressed text from the E5786 `/proc/config.gz`.
- `e5786-exported-symbols.txt`: exported kernel symbol names extracted from `/proc/kallsyms`.

Use the probe script documented in the parent README. Do not substitute a config from E3372h/V7R11 or another firmware.

The build workflow will stop if either file is missing.
