#!/bin/bash
# Optional collectors loader.
# Only runs collectors that are enabled in $LUMENMON_DATA/config.

CONFIG="$LUMENMON_DATA/config"

# Load config if exists
declare -A ENABLED_COLLECTORS
if [[ -f "$CONFIG" ]]; then
    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" == \#* ]] && continue
        ENABLED_COLLECTORS["$key"]="$value"
    done < "$CONFIG"
fi

# Export for collectors to read
export LUMENMON_CONFIG_LOADED=1

# Run enabled optional collectors
for collector in "$LUMENMON_HOME/collectors/optional"/*.sh; do
    [[ "$(basename "$collector")" == "_init.sh" ]] && continue
    [[ ! -f "$collector" ]] && continue

    # Get collector name (filename without .sh)
    name=$(basename "$collector" .sh)

    # Check if enabled in config
    if [[ "${ENABLED_COLLECTORS[$name]:-0}" == "1" ]]; then
        run_collector "$name" "$collector"
    fi
done
