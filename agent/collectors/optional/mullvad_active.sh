#!/bin/bash
# Mullvad VPN status via API check.
# Reports 1 if traffic exits via Mullvad, 0 if not.
# Config: mullvad_active=1 to enable, mullvad_required=1 to alert on disconnect.

METRIC="mullvad_active"

source "$LUMENMON_HOME/core/mqtt/publish.sh"

# Load config for mullvad_required setting
CONFIG="$LUMENMON_DATA/config"
mullvad_required=0
[[ -f "$CONFIG" ]] && source "$CONFIG"

while true; do
    connected=0
    server=""

    response=$(curl -s --max-time 10 https://am.i.mullvad.net/json 2>/dev/null)

    if [[ -n "$response" ]]; then
        mullvad_exit=$(echo "$response" | jq -r '.mullvad_exit_ip // false')
        if [[ "$mullvad_exit" == "true" ]]; then
            connected=1
            server=$(echo "$response" | jq -r '.mullvad_exit_ip_hostname // "unknown"')
        fi
    fi

    # If required, set bounds so 0 = failure
    if [[ "${mullvad_required:-0}" == "1" ]]; then
        publish_metric "$METRIC" "$connected" "INTEGER" "$CYCLE" 1 1
    else
        publish_metric "$METRIC" "$connected" "INTEGER" "$CYCLE"
    fi

    # Also report server name if connected
    if [[ "$connected" == "1" && -n "$server" ]]; then
        publish_metric "mullvad_server" "$server" "TEXT" "$CYCLE"
    fi

    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && exit 0
    sleep $CYCLE
done
