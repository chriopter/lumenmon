#!/usr/bin/env bash
# Simplified demo: single script plotting three metrics with ttyplot
# Rotates CPU%, MEM%, and LOAD% (1m normalized by cores). Uses color per metric.

set -euo pipefail

TTYplot_BIN=${TTYplot_BIN:-ttyplot}
SAMPLE_INT=${SAMPLE_INT:-1}
PER_METRIC_SECS=${PER_METRIC_SECS:-20}

command -v "$TTYplot_BIN" >/dev/null 2>&1 || { echo "ttyplot not found" >&2; exit 1; }

bold() { tput bold 2>/dev/null || true; }
normal() { tput sgr0 2>/dev/null || true; }
fg() { tput setaf "$1" 2>/dev/null || printf '\033[3%sm' "$1"; }

cores() { grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1; }

sample_cpu() {
  local duration=${1:-0}
  local start=$SECONDS
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
    (( duration>0 && SECONDS-start >= duration )) && break
  done
}

sample_mem() {
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
  local duration=${1:-0}
  local start=$SECONDS
  local c; c=$(cores); (( c<1 )) && c=1
  while :; do
    local l; l=$(awk '{print $1}' /proc/loadavg)
    awk -v l="$l" -v c="$c" 'BEGIN{p=(l/c)*100; if(p<0)p=0; printf("%.2f\n", p)}'
    sleep "$SAMPLE_INT"
    (( duration>0 && SECONDS-start >= duration )) && break
  done
}

plot_once() {
  local title=$1 unit=$2 color=$3 sampler=$4
  clear
  bold; fg "$color"; echo "== $title (press Ctrl+C to skip) =="; normal
  # Stream sampler into ttyplot; limit duration with timeout wrapping the consumer
  case "$sampler" in
    cpu)  sample_cpu  "$PER_METRIC_SECS" ;;
    mem)  sample_mem  "$PER_METRIC_SECS" ;;
    load) sample_load "$PER_METRIC_SECS" ;;
    sample_cpu|sample_mem|sample_load) "$sampler" "$PER_METRIC_SECS" ;;
    *) sample_cpu "$PER_METRIC_SECS" ;;
  esac | "$TTYplot_BIN" -t "$title" -u "$unit" || true
}

main() {
  while :; do
    plot_once "CPU %" "%" 2 cpu
    plot_once "MEM %" "%" 5 mem
    plot_once "LOAD % (1m/cores)" "%" 6 load
  done
}

main "$@"
