#!/usr/bin/env bash
# ttyplot-based live visualization demo (pure Bash)
# Shows auto-scrolling history using ttyplot for multiple metrics.
# Metrics: cpu %, mem %, load % (normalized), net throughput (Mb/s)
#
# Usage:
#   ./ttyplot_demo.sh cpu|mem|load|net
#   ./ttyplot_demo.sh rotate   # rotate through all metrics (15s each)

set -euo pipefail

TTYplot_BIN=${TTYplot_BIN:-ttyplot}
DURATION_PER=${DURATION_PER:-15}  # seconds per metric when rotating
SAMPLE_INT=${SAMPLE_INT:-1}       # seconds between samples

require() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
require "$TTYplot_BIN"

cores() {
  # number of logical CPUs
  grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1
}

sample_cpu() {
  # prints overall CPU usage % once per second
  local duration=${1:-0}
  local start=$SECONDS
  local line u n s i io irq sirq steal guest guest_nice
  # prime
  read -r line < /proc/stat
  set -- $line; shift
  u=$1; n=$2; s=$3; i=$4; io=$5; irq=$6; sirq=$7; steal=${8:-0}
  local pt=$((u+n+s+i+io+irq+sirq+steal)) pu=$((u+n+s))
  while :; do
    sleep "$SAMPLE_INT"
    read -r line < /proc/stat
    set -- $line; shift
    u=$1; n=$2; s=$3; i=$4; io=$5; irq=$6; sirq=$7; steal=${8:-0}
    local t=$((u+n+s+i+io+irq+sirq+steal)) used=$((u+n+s))
    local du=$((used - pu)) dt=$((t - pt))
    awk -v du="$du" -v dt="$dt" 'BEGIN{printf("%.2f\n", dt>0 ? (du/dt)*100 : 0)}'
    pu=$used; pt=$t
    (( duration>0 && SECONDS-start >= duration )) && break
  done
}

sample_mem() {
  # prints memory used % once per second
  local duration=${1:-0}
  local start=$SECONDS
  while :; do
    local tot avail
    tot=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
    avail=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
    awk -v t="$tot" -v a="$avail" 'BEGIN{u=(t-a)/t*100; if(u<0)u=0; if(u>100)u=100; printf("%.2f\n", u)}'
    sleep "$SAMPLE_INT"
    (( duration>0 && SECONDS-start >= duration )) && break
  done
}

sample_load() {
  # prints normalized load % (1-min load vs cores) once per second
  local duration=${1:-0}
  local start=$SECONDS
  local c; c=$(cores)
  (( c<1 )) && c=1
  while :; do
    local l; l=$(awk '{print $1}' /proc/loadavg)
    awk -v l="$l" -v c="$c" 'BEGIN{p=(l/c)*100; if(p<0)p=0; printf("%.2f\n", p)}'
    sleep "$SAMPLE_INT"
    (( duration>0 && SECONDS-start >= duration )) && break
  done
}

sample_net() {
  # prints combined (rx+tx) throughput in Mb/s across all non-lo interfaces
  local duration=${1:-0}
  local start=$SECONDS
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
    (( duration>0 && SECONDS-start >= duration )) && break
  done
}

plot_cpu()  { sample_cpu  "${1:-0}" | "$TTYplot_BIN" -t "CPU %"   -u "%"; }
plot_mem()  { sample_mem  "${1:-0}" | "$TTYplot_BIN" -t "MEM %"   -u "%"; }
plot_load() { sample_load "${1:-0}" | "$TTYplot_BIN" -t "LOAD % (1m/cores)" -u "%"; }
plot_net()  { sample_net  "${1:-0}" | "$TTYplot_BIN" -t "NET Mb/s (rx+tx)" -u "Mb/s"; }

rotate() {
  while :; do
    plot_cpu  "$DURATION_PER" || true
    plot_mem  "$DURATION_PER" || true
    plot_load "$DURATION_PER" || true
    plot_net  "$DURATION_PER" || true
  done
}

case "${1:-rotate}" in
  cpu)  plot_cpu  ;;
  mem)  plot_mem  ;;
  load) plot_load ;;
  net)  plot_net  ;;
  rotate) rotate  ;;
  *) echo "Usage: $0 {cpu|mem|load|net|rotate}" >&2; exit 1 ;;
esac

