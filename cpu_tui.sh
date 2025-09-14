#!/usr/bin/env bash
# Minimal CPU TUI in pure bash (no Python, no external deps)
# - Samples CPU 10 Hz from /proc/stat (overall + per-core)
# - Shows last 60s sparkline for overall CPU usage
# - Press 'e' to expand/collapse per-core charts
# - Press 'q' to quit

set -euo pipefail

SAMPLE_HZ=10           # samples per second
RING_SECONDS=60        # last minute
RING_SIZE=$((SAMPLE_HZ * RING_SECONDS))  # 600

# Terminal helpers
hide_cursor() { tput civis 2>/dev/null || true; }
show_cursor() { tput cnorm 2>/dev/null || true; }
clr() { tput clear 2>/dev/null || printf '\\033[2J\\033[H'; }
cup() { tput cup "$1" "$2" 2>/dev/null || printf '\\033[%d;%dH' "$(( $1 + 1 ))" "$(( $2 + 1 ))"; }

# UTF-8 spark chars; falls back to ASCII if locale/terminal lacks blocks
SPARK_CHARS=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")

supports_utf8() {
  # crude check: print a block and see if width is 1
  local w block="${SPARK_CHARS[7]}"; w=$(printf "%s" "$block" | wc -m)
  [ "$w" -eq 1 ]
}

if ! supports_utf8; then
  SPARK_CHARS=("." ":" "-" "=" "+" "#" "#" "#")
fi

# Color helpers
cset() { tput setaf "$1" 2>/dev/null || printf '\033[3%sm' "$1"; }
creset() { tput sgr0 2>/dev/null || printf '\033[0m'; }

color_for_pct10() {
  local x10=$1
  if (( x10 <= 500 )); then echo 2; return; fi   # green <= 50%
  if (( x10 <= 800 )); then echo 3; return; fi   # yellow <= 80%
  echo 1                                           # red > 80%
}

# Global state
declare -a PREV_IDLE_ALL PREV_TOTAL_ALL
declare -a PREV_IDLE CORES_IDLE PREV_TOTAL CORES_TOTAL
declare -a RING_ALL
RING_ALL_IDX=0
RING_ALL_LEN=0

# Per-core rings are arrays-of-arrays; we store in associative arrays by index
declare -A RING_CORE_IDX RING_CORE_LEN
declare -A RING_CORE_ARR

read_procstat() {
  local line name; local -a vals
  local all_idle=0 all_total=0
  local cores_idle=() cores_total=()
  while IFS= read -r line; do
    [[ $line == cpu* ]] || break
    read -r -a vals <<<"${line#cpu}"
    # name is first token before numbers
    name=${line%% *}
    # skip label (cpu/cpuN) to get numbers
    local rest=${line#* }
    local -a n; read -r -a n <<<"$rest"
    local idle=0 total=0
    # user nice system idle iowait irq softirq steal guest guest_nice
    local c0=${n[0]:-0} c1=${n[1]:-0} c2=${n[2]:-0} c3=${n[3]:-0} c4=${n[4]:-0} c5=${n[5]:-0} c6=${n[6]:-0} c7=${n[7]:-0} c8=${n[8]:-0} c9=${n[9]:-0}
    idle=$(( c3 + c4 ))
    total=$(( c0 + c1 + c2 + c3 + c4 + c5 + c6 + c7 + c8 + c9 ))

    if [[ $name == cpu ]]; then
      all_idle=$idle; all_total=$total
    elif [[ $name == cpu[0-9]* ]]; then
      cores_idle+=("$idle"); cores_total+=("$total")
    fi
  done < /proc/stat

  # set globals via namerefs
  PREV_IDLE_ALL=("$all_idle")
  PREV_TOTAL_ALL=("$all_total")
  PREV_IDLE=("${cores_idle[@]}")
  PREV_TOTAL=("${cores_total[@]}")
}

util_pct() {
  local pidle=$1 ptotal=$2 idle=$3 total=$4
  local didle=$(( idle - pidle ))
  local dtotal=$(( total - ptotal ))
  if (( dtotal <= 0 )); then echo 0; return; fi
  local used=$(( dtotal - didle ))
  # percent with one decimal (x10)
  local pct_x10=$(( (used * 1000) / dtotal ))
  # convert to float-like string with one decimal
  printf '%.1f' "$((pct_x10/10)).$((pct_x10%10))"
}

sample_cpu() {
  local line name; local -a n
  local all_idle=0 all_total=0
  local cores_idle=() cores_total=()
  while IFS= read -r line; do
    [[ $line == cpu* ]] || break
    name=${line%% *}
    local rest=${line#* }
    read -r -a n <<<"$rest"
    local c0=${n[0]:-0} c1=${n[1]:-0} c2=${n[2]:-0} c3=${n[3]:-0} c4=${n[4]:-0} c5=${n[5]:-0} c6=${n[6]:-0} c7=${n[7]:-0} c8=${n[8]:-0} c9=${n[9]:-0}
    local idle=$(( c3 + c4 ))
    local total=$(( c0 + c1 + c2 + c3 + c4 + c5 + c6 + c7 + c8 + c9 ))
    if [[ $name == cpu ]]; then
      all_idle=$idle; all_total=$total
    elif [[ $name == cpu[0-9]* ]]; then
      cores_idle+=("$idle"); cores_total+=("$total")
    fi
  done < /proc/stat

  # overall
  local overall
  overall=$(util_pct "${PREV_IDLE_ALL[0]}" "${PREV_TOTAL_ALL[0]}" "$all_idle" "$all_total")
  PREV_IDLE_ALL=("$all_idle"); PREV_TOTAL_ALL=("$all_total")

  # per-core
  local -a pcs=()
  local count=${#cores_idle[@]}
  # adjust prev arrays if CPU count changed
  if (( ${#PREV_IDLE[@]} != count )); then
    PREV_IDLE=("${cores_idle[@]}"); PREV_TOTAL=("${cores_total[@]}")
  fi
  for ((i=0; i < count; i++)); do
    pcs+=("$(util_pct "${PREV_IDLE[$i]}" "${PREV_TOTAL[$i]}" "${cores_idle[$i]}" "${cores_total[$i]}")")
  done
  PREV_IDLE=("${cores_idle[@]}"); PREV_TOTAL=("${cores_total[@]}")

  echo "$overall|${pcs[*]}"
}

ring_push_all() {
  local val=$1
  RING_ALL[$RING_ALL_IDX]=$val
  RING_ALL_IDX=$(( (RING_ALL_IDX + 1) % RING_SIZE ))
  if (( RING_ALL_LEN < RING_SIZE )); then RING_ALL_LEN=$((RING_ALL_LEN + 1)); fi
}

ring_push_core() {
  local idx val key
  idx=$1; val=$2; key="c$idx"
  # initialize if absent
  : "${RING_CORE_IDX[$key]:=0}"
  : "${RING_CORE_LEN[$key]:=0}"
  local pos=${RING_CORE_IDX[$key]}
  RING_CORE_ARR["$key,$pos"]=$val
  pos=$(( (pos + 1) % RING_SIZE ))
  RING_CORE_IDX[$key]=$pos
  local l=${RING_CORE_LEN[$key]}
  if (( l < RING_SIZE )); then RING_CORE_LEN[$key]=$((l + 1)); fi
}

# Convert a percentage string with one decimal (e.g., 12.3) to int-tenths (123)
as_int10() {
  local s="$1"
  if [[ "$s" == *.* ]]; then
    local a=${s%.*}
    local b=${s#*.}
    b=${b:0:1}
    printf '%d' "${a}${b}"
  else
    printf '%d' "${s}0"
  fi
}

# Format int-tenths (e.g., 123) back to 12.3
fmt_pct10() {
  local x10=$1
  printf '%d.%d' $((x10/10)) $((x10%10))
}

# Compute min/avg/max over overall ring (int-tenths)
ring_min_max_avg_all10() {
  local len=$RING_ALL_LEN; local start=$(( (RING_ALL_IDX - len + RING_SIZE) % RING_SIZE ))
  local i=0; local min=10000 max=-1 sum=0
  while (( i < len )); do
    local idx=$(( (start + i) % RING_SIZE ))
    local v=${RING_ALL[$idx]:-0}
    local vi10; vi10=$(as_int10 "$v")
    (( vi10 < min )) && min=$vi10
    (( vi10 > max )) && max=$vi10
    sum=$(( sum + vi10 ))
    i=$((i+1))
  done
  local avg=0; (( len > 0 )) && avg=$(( sum / len ))
  echo "$min $avg $max"
}

sparkline_all() {
  local width=$1
  local len=$RING_ALL_LEN
  if (( len == 0 )); then printf '%*s' "$width" ""; return; fi
  local start=$(( (RING_ALL_IDX - len + RING_SIZE) % RING_SIZE ))
  local step_num=$len
  local step_den=$width
  local out=""
  for ((x=0; x<width; x++)); do
    # compute range [a,b) in logical positions
    local a=$(( (x * step_num) / step_den ))
    local b=$(( ((x+1) * step_num) / step_den ))
    (( b <= a )) && b=$((a+1))
    local sum=0 cnt=0
    for ((k=a; k<b; k++)); do
      local idx=$(( (start + k) % RING_SIZE ))
      local v=${RING_ALL[$idx]:-0}
      local vi10; vi10=$(as_int10 "$v")
      sum=$((sum + vi10)); cnt=$((cnt+1))
    done
    local avg10=$(( sum / cnt ))
    # map 0..1000 (x10) -> 0..7
    local lvl=$(( (avg10 * 7) / 1000 ))
    (( lvl < 0 )) && lvl=0; (( lvl > 7 )) && lvl=7
    out+="${SPARK_CHARS[$lvl]}"
  done
  printf '%s' "$out"
}

sparkline_core() {
  local idx width key
  idx=$1; width=$2; key="c$idx"
  local len=${RING_CORE_LEN[$key]:-0}
  if (( len == 0 )); then printf '%*s' "$width" ""; return; fi
  local start=$(( (RING_CORE_IDX[$key] - len + RING_SIZE) % RING_SIZE ))
  local step_num=$len step_den=$width
  local out=""
  for ((x=0; x<width; x++)); do
    local a=$(( (x * step_num) / step_den ))
    local b=$(( ((x+1) * step_num) / step_den ))
    (( b <= a )) && b=$((a+1))
    local sum=0 cnt=0
    for ((k=a; k<b; k++)); do
      local p=$(( (start + k) % RING_SIZE ))
      local v=${RING_CORE_ARR["$key,$p"]:-0}
      local vi=${v%.*}
      sum=$((sum + vi)); cnt=$((cnt+1))
    done
    local avg=$(( sum / cnt ))
    local lvl=$(( (avg * 7) / 100 ))
    (( lvl < 0 )) && lvl=0; (( lvl > 7 )) && lvl=7
    out+="${SPARK_CHARS[$lvl]}"
  done
  printf '%s' "$out"
}

# Draw a labeled stat bar at row,col
draw_stat_bar() {
  local row=$1 col=$2 label=$3 pct10=$4 width=$5
  local pct_str; pct_str=$(fmt_pct10 "$pct10")
  local fill=$(( (pct10 * width) / 1000 ))
  (( fill < 0 )) && fill=0; (( fill > width )) && fill=$width
  local color; color=$(color_for_pct10 "$pct10")

  local left="$(printf '%-3s %6s%% ' "$label" "$pct_str")"
  cup "$row" "$col"; printf '%s' "$left"
  cset "$color"
  printf '['
  printf '%*s' "$fill" '' | tr ' ' '█'
  printf '%*s' "$((width-fill))" '' | tr ' ' '░'
  printf ']'
  creset
}

draw() {
  local overall=$1; shift
  local -a pcs=("$@")
  local rows cols; rows=$(tput lines 2>/dev/null || echo 24); cols=$(tput cols 2>/dev/null || echo 80)
  local w=$cols
  local latest10; latest10=$(as_int10 "$overall")
  local title=" LUMENMON CPU TUI (bash, 10 Hz, last 60s)  [q] quit  [e] per-core: $([[ ${EXPANDED:-0} -eq 1 ]] && echo ON || echo OFF) "
  cup 0 0; printf '%-*s' "$w" "$title"

  # Overall gauge
  local gauge_w=$(( w / 4 )); (( gauge_w < 10 )) && gauge_w=10; (( gauge_w > 30 )) && gauge_w=30
  local pct_int=${overall%.*}
  local fill=$(( (pct_int * gauge_w) / 100 ))
  local bar="$(printf '%*s' "$fill" '' | tr ' ' '█')"; bar+="$(printf '%*s' "$((gauge_w-fill))" '' | tr ' ' '░')"
  cup 2 0; printf 'Overall CPU: %5.1f%%' "$overall"
  local gauge_color; gauge_color=$(color_for_pct10 "$latest10")
  cup 3 0; cset "$gauge_color"; printf '[%s]' "$bar"; creset

  # Stats (min/avg/max) textual summary next to gauge
  local min10_t avg10_t max10_t; read -r min10_t avg10_t max10_t < <(ring_min_max_avg_all10)
  local min_t; min_t=$(fmt_pct10 "$min10_t")
  local avg_t; avg_t=$(fmt_pct10 "$avg10_t")
  local max_t; max_t=$(fmt_pct10 "$max10_t")
  cup 2 $((gauge_w + 15)); printf 'min %5s%%  avg %5s%%  max %5s%%' "$min_t" "$avg_t" "$max_t"

  # Overall sparkline
  local spark_w=$(( w - 2 )); (( spark_w < 10 )) && spark_w=10
  local spark; spark=$(sparkline_all "$spark_w")
  # Color overall sparkline based on latest pct
  local color=$(color_for_pct10 "$latest10")
  cup 5 0; cset "$color"; printf '%.*s' "$((w-1))" "$spark"; creset

  local row=7
  if [[ ${EXPANDED:-0} -eq 1 ]]; then
    cup $row 0; printf 'Per-core usage (last 60s):'
    row=$((row+1))
    local label_w=14
    local pc_w=$(( w - label_w - 2 )); (( pc_w < 10 )) && pc_w=10
    local i
    for ((i=0; i<${#pcs[@]}; i++)); do
      if (( row >= rows - 1 )); then break; fi
      local cur=${pcs[$i]}
      cup $row 0; printf 'cpu%02d %5.1f%% ' "$i" "$cur"
      local pc_s; pc_s=$(sparkline_core "$i" "$pc_w")
      cup $row $label_w; printf '%.*s' "$((w-label_w-1))" "$pc_s"
      row=$((row+1))
    done
  fi

  # Statistics bars for last minute (min/avg/max)
  local min10 avg10 max10
  read -r min10 avg10 max10 < <(ring_min_max_avg_all10)
  local stats_w=$(( w - 2 )); (( stats_w < 30 )) && stats_w=30
  local bar_w=$(( stats_w - 20 ))
  (( bar_w < 10 )) && bar_w=10
  row=$((row + 1))
  draw_stat_bar $row 0 "MIN" "$min10" "$bar_w"
  row=$((row + 1))
  draw_stat_bar $row 0 "AVG" "$avg10" "$bar_w"
  row=$((row + 1))
  draw_stat_bar $row 0 "MAX" "$max10" "$bar_w"
}

restore_term() {
  stty echo -icanon time 0 min 0 2>/dev/null || true
  show_cursor
}

main() {
  EXPANDED=0
  hide_cursor
  trap restore_term EXIT INT TERM
  stty -echo -icanon time 0 min 0 2>/dev/null || true
  clr

  read_procstat # initialize prev counters

  # Prime first sample to size per-core rings
  local out overall; out=$(sample_cpu)
  overall=${out%%|*}
  local rest=${out#*|}
  IFS=' ' read -r -a pcs <<<"$rest"
  ring_push_all "$overall"
  local i; for ((i=0; i<${#pcs[@]}; i++)); do ring_push_core "$i" "${pcs[$i]}"; done

  local period_ns=$(( 1000000000 / SAMPLE_HZ ))
  local next_ns=$(date +%s%N)

  while true; do
    # input
    if read -rsn1 -t 0.001 key; then
      case "$key" in
        q|Q) break ;;
        e|E) EXPANDED=$((1-EXPANDED)) ;;
      esac
    fi

    # sample
    out=$(sample_cpu)
    overall=${out%%|*}
    rest=${out#*|}
    IFS=' ' read -r -a pcs <<<"$rest"
    ring_push_all "$overall"
    for ((i=0; i<${#pcs[@]}; i++)); do ring_push_core "$i" "${pcs[$i]}"; done

    # draw
    draw "$overall" "${pcs[@]}"

    # sleep until next tick
    next_ns=$(( next_ns + period_ns ))
    local now_ns=$(date +%s%N)
    local diff=$(( next_ns - now_ns ))
    if (( diff > 0 )); then
      # convert ns to seconds with 3 decimals
      local ms=$(( diff / 1000000 ))
      # bash sleep supports .ms
      sleep ".${ms}"
    else
      next_ns=$now_ns
    fi
  done
}

main "$@"
