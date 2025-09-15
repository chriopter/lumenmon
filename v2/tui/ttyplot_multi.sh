#!/usr/bin/env bash
# Multi-graph ttyplot demo in one screen (CPU, MEM, LOAD)
# Uses tmux to run three ttyplot instances side-by-side vertically.

set -euo pipefail

TTYplot_BIN=${TTYplot_BIN:-ttyplot}
SAMPLE_INT=${SAMPLE_INT:-1}
SESSION_NAME=${SESSION_NAME:-lmplot}

# Ensure tmux uses a writable tmpfs even when root FS is read-only
: "${TMUX_TMPDIR:=/dev/shm}"
export TMUX_TMPDIR

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
require "$TTYplot_BIN"
require tmux

cores() { grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1; }

sample_cpu() {
  local line u n s i io irq sirq steal
  read -r line < /proc/stat; set -- $line; shift
  u=$1; n=$2; s=$3; i=$4; io=$5; irq=$6; sirq=$7; steal=${8:-0}
  local pt=$((u+n+s+i+io+irq+sirq+steal)) pu=$((u+n+s))
  while :; do
    sleep "$SAMPLE_INT"
    read -r line < /proc/stat; set -- $line; shift
    u=$1; n=$2; s=$3; i=$4; io=$5; irq=$6; sirq=$7; steal=${8:-0}
    local t=$((u+n+s+i+io+irq+sirq+steal)) used=$((u+n+s))
    local du=$((used - pu)) dt=$((t - pt))
    awk -v du="$du" -v dt="$dt" 'BEGIN{printf("%.2f\n", dt>0 ? (du/dt)*100 : 0)}'
    pu=$used; pt=$t
  done
}

sample_mem() {
  while :; do
    local tot avail
    tot=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
    avail=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
    awk -v t="$tot" -v a="$avail" 'BEGIN{u=(t-a)/t*100; if(u<0)u=0; if(u>100)u=100; printf("%.2f\n", u)}'
    sleep "$SAMPLE_INT"
  done
}

sample_load() {
  local c; c=$(cores); (( c<1 )) && c=1
  while :; do
    local l; l=$(awk '{print $1}' /proc/loadavg)
    awk -v l="$l" -v c="$c" 'BEGIN{p=(l/c)*100; if(p<0)p=0; printf("%.2f\n", p)}'
    sleep "$SAMPLE_INT"
  done
}

# Combined network throughput (rx+tx) across all non-lo interfaces in Mb/s
sample_net() {
  local rx tx prev sum
  read -r rx tx < <(awk -F'[: ]+' '/:/ && $1!="lo" {rx+=$3; tx+=$11} END{print rx+0, tx+0}' /proc/net/dev)
  prev=$((rx+tx))
  while :; do
    sleep "$SAMPLE_INT"
    read -r rx tx < <(awk -F'[: ]+' '/:/ && $1!="lo" {rx+=$3; tx+=$11} END{print rx+0, tx+0}' /proc/net/dev)
    sum=$((rx+tx))
    local d=$((sum - prev))
    # bytes/sec -> megabits/sec
    awk -v bps="$d" 'BEGIN{printf("%.2f\n", (bps*8)/1000000)}'
    prev=$sum
  done
}

# Per-core CPU usage % for a given core index
sample_core() {
  local core=${1:-0}
  local line u n s i io irq sirq steal
  # prime
  read -r line < <(grep -m1 "^cpu${core} " /proc/stat)
  set -- $line; shift
  u=$1; n=$2; s=$3; i=$4; io=$5; irq=$6; sirq=$7; steal=${8:-0}
  local pt=$((u+n+s+i+io+irq+sirq+steal)) pu=$((u+n+s))
  while :; do
    sleep "$SAMPLE_INT"
    read -r line < <(grep -m1 "^cpu${core} " /proc/stat)
    set -- $line; shift
    u=$1; n=$2; s=$3; i=$4; io=$5; irq=$6; sirq=$7; steal=${8:-0}
    local t=$((u+n+s+i+io+irq+sirq+steal)) used=$((u+n+s))
    local du=$((used - pu)) dt=$((t - pt))
    awk -v du="$du" -v dt="$dt" 'BEGIN{printf("%.2f\n", dt>0 ? (du/dt)*100 : 0)}'
    pu=$used; pt=$t
  done
}

pane() {
  case "${1}" in
    cpu)  sample_cpu  | "$TTYplot_BIN" -t "CPU %"  -u "%" ;;
    mem)  sample_mem  | "$TTYplot_BIN" -t "MEM %"  -u "%" ;;
    load) sample_load | "$TTYplot_BIN" -t "LOAD % (1m/cores)" -u "%" ;;
    net)  sample_net  | "$TTYplot_BIN" -t "NET Mb/s (rx+tx)" -u "Mb/s" ;;
    core) shift; cidx=${1:-0}; sample_core "$cidx" | "$TTYplot_BIN" -t "CPU${cidx} %" -u "%" ;;
    *) echo "unknown pane: $1" >&2; exit 1 ;;
  esac
}

multi() {
  # Kill existing session if present
  tmux has-session -t "$SESSION_NAME" 2>/dev/null && tmux kill-session -t "$SESSION_NAME"

  # First pane: overall CPU or per-core if CORE_IDX is provided
  if [[ ${CORE_IDX:-} =~ ^[0-9]+$ ]]; then
    tmux new-session -d -s "$SESSION_NAME" \
      "/usr/local/bin/ttyplot_multi.sh pane core ${CORE_IDX}"
  else
    tmux new-session -d -s "$SESSION_NAME" \
      "/usr/local/bin/ttyplot_multi.sh pane cpu"
  fi

  # Split for MEM
  tmux split-window -v -t "$SESSION_NAME" \
    "/usr/local/bin/ttyplot_multi.sh pane mem"

  # Split again for LOAD and NET
  tmux split-window -v -t "$SESSION_NAME" \
    "/usr/local/bin/ttyplot_multi.sh pane load"
  tmux split-window -v -t "$SESSION_NAME" \
    "/usr/local/bin/ttyplot_multi.sh pane net"

  # Layout and style
  tmux select-layout -t "$SESSION_NAME" even-vertical
  tmux set-option -g -t "$SESSION_NAME" status off
  tmux set-option -g -t "$SESSION_NAME" pane-border-style fg=colour240
  tmux set-option -g -t "$SESSION_NAME" pane-active-border-style fg=colour10

  # Attach
  exec tmux attach -t "$SESSION_NAME"
}

case "${1:-multi}" in
  pane) shift; pane "$@" ;;
  multi) multi ;;
  *) echo "Usage: $0 [multi|pane <cpu|mem|load>]" >&2; exit 1 ;;
esac
