# ttyplot Demo (Bash)

Auto-scrolling terminal graphs powered by ttyplot. Shows CPU, MEM, and LOAD simultaneously using tmux panes, or runs the simple single-plot rotator.

## Build

```
docker build -f Dockerfile.ttyplot -t ttyplot-demo .
```

## Run (recommended)

```
# Use host PID namespace so the container can read host /proc/stat and /proc/net

docker run --rm -it \
  --pid=host \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  -e TERM=xterm-256color \
  -e TMUX_TMPDIR=/dev/shm \
  --name ttyplot-demo \
  ttyplot-demo
```

- Default: four panes (CPU %, MEM %, LOAD % normalized to cores, NET Mb/s) updating at 1 Hz.
- Press Ctrl+C to stop.
 - If your Docker setup lacks /dev/shm, add: `--tmpfs /tmp:rw,nosuid,nodev,mode=1777 -e TMUX_TMPDIR=/tmp`.

## CLI Modes
- Multi-pane (default): `/usr/local/bin/ttyplot_multi.sh multi`
  - Optional: set `CORE_IDX=<n>` to show CPU core `<n>` instead of overall CPU in the top pane.
- Single-plot rotator: `/usr/local/bin/ttyplot3.sh`

## Options
- `SAMPLE_INT` (default 1): sampling interval seconds
- `TTYplot_BIN` (default `ttyplot`): path to ttyplot binary

## Notes
- ttyplot auto-scales to terminal width; wider terminals show more history.
- To approximate a “last 10 minutes” view at 1 Hz, use a ~600-column terminal or reduce sampling to 0.5–0.2 Hz.
- No host filesystem mounts are required; metrics read from `/proc`.
