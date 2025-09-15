# CPU TUI (Bash) — Secure Dockerized Demo

A minimal Bash-only TUI that renders CPU usage at 10 Hz with a last‑minute sparkline. Runs as a non‑root user in a small Alpine container.

## Build

```
docker build -f Dockerfile.cpu-tui -t cpu-tui .
```

## Run (recommended flags)

```
# Read host CPU via /proc and share PID namespace for accurate stats
# Run non-root, drop all capabilities, no-new-privileges, read-only FS

docker run --rm -it \
  --pid=host \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  -e TERM=xterm-256color \
  --name cpu-tui \
  cpu-tui
```

Keys
- `q` quit
- `e` expand/collapse per‑core view

Notes
- For per-core rendering and Unicode blocks, use a UTF‑8 terminal. Falls back to ASCII if blocks are unsupported.
- Without `--pid=host`, the TUI will show the container’s CPU view instead of the host.
- No host filesystem mounts are required; the app reads `/proc/stat` only.

