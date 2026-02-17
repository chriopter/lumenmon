#!/bin/bash
# Collects CPU, GPU, NVMe, and lm-sensors temperatures on hardware hosts.
# Publishes per-sensor thermal telemetry with conservative alert thresholds.

RHYTHM="CYCLE"

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

while true; do
    if command -v sensors >/dev/null 2>&1; then
        cpu_temp=$(LC_ALL=C sensors 2>/dev/null | awk '/Package id 0:|Tctl:|CPU Temperature:/ {gsub(/\+|°C/,"",$4); print $4; exit}')
        if [ -n "$cpu_temp" ]; then
            publish_metric "hardware_temp_cpu_c" "$cpu_temp" "REAL" "$CYCLE" 0 90
        fi

        current_chip=""
        while IFS= read -r line; do
            [ -z "$line" ] && continue

            if [[ "$line" != " "* ]] && [[ "$line" != $'\t'* ]] && [[ "$line" != Adapter:* ]]; then
                current_chip="$line"
                continue
            fi

            if [[ "$line" =~ ^[[:space:]]*([^:]+):[[:space:]]*([+-]?[0-9]+(\.[0-9]+)?)°C ]]; then
                label="${BASH_REMATCH[1]}"
                temp="${BASH_REMATCH[2]}"
                temp="${temp#+}"

                if awk -v t="$temp" 'BEGIN {exit !(t >= -10 && t <= 120)}'; then
                    sensor_key=$(printf '%s_%s' "$current_chip" "$label" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' | tr -s '_')
                    sensor_key="${sensor_key#_}"
                    sensor_key="${sensor_key%_}"

                    [ -z "$sensor_key" ] && continue
                    publish_metric "hardware_temp_${sensor_key}_c" "$temp" "REAL" "$CYCLE" 0 90
                fi
            fi
        done < <(LC_ALL=C sensors 2>/dev/null)
    fi

    if command -v nvidia-smi >/dev/null 2>&1; then
        while IFS=',' read -r gpu_index gpu_temp; do
            gpu_index="$(echo "$gpu_index" | tr -d ' ')"
            gpu_temp="$(echo "$gpu_temp" | tr -d ' ')"
            [ -z "$gpu_index" ] && continue
            [ -z "$gpu_temp" ] && continue

            if awk -v t="$gpu_temp" 'BEGIN {exit !(t >= -10 && t <= 120)}'; then
                publish_metric "hardware_temp_gpu_${gpu_index}_c" "$gpu_temp" "INTEGER" "$CYCLE" 0 90
            fi
        done < <(nvidia-smi --query-gpu=index,temperature.gpu --format=csv,noheader,nounits 2>/dev/null || true)
    fi

    if command -v nvme >/dev/null 2>&1; then
        while read -r dev; do
            [ -z "$dev" ] && continue
            key=$(basename "$dev" | tr '.-' '__')
            temp=$(nvme smart-log "$dev" 2>/dev/null | awk '
                BEGIN { IGNORECASE=1 }
                /temperature/ {
                    if (match($0, /\(([0-9]+)[[:space:]]*C\)/, m)) {
                        print m[1]
                        exit
                    }
                    if (match($0, /temperature[^0-9]*([0-9]+)[[:space:]]*C/, m)) {
                        print m[1]
                        exit
                    }
                }
            ')
            if [ -n "$temp" ] && awk -v t="$temp" 'BEGIN {exit !(t >= -10 && t <= 120)}'; then
                publish_metric "hardware_temp_nvme_${key}_c" "$temp" "INTEGER" "$CYCLE" 0 70
            fi
        done < <(nvme list 2>/dev/null | awk '/^\/dev\/nvme/ {print $1}')
    fi

    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep "$CYCLE"
done
