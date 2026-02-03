#!/bin/bash
# Reads local mail from /var/mail/root and forwards via MQTT.
# Parses mbox format, tracks position to avoid resending.

# Config
METRIC="generic_mail"
CHECK_INTERVAL=60  # Check every 60 seconds

set -euo pipefail
source "$LUMENMON_HOME/core/mqtt/publish.sh"

# Possible mail file locations (can override with LUMENMON_MAIL_FILE)
if [ -n "${LUMENMON_MAIL_FILE:-}" ]; then
    MAIL_LOCATIONS=("$LUMENMON_MAIL_FILE")
else
    MAIL_LOCATIONS=(
        "/var/mail/root"
        "/var/spool/mail/root"
        "/var/mail/$USER"
        "/var/spool/mail/$USER"
    )
fi

# State file to track processed messages
STATE_FILE="$LUMENMON_DATA/mail_state"

# Find the mail file
find_mail_file() {
    for loc in "${MAIL_LOCATIONS[@]}"; do
        if [ -f "$loc" ] && [ -r "$loc" ]; then
            echo "$loc"
            return 0
        fi
    done
    return 1
}

# Get file inode and size for change detection
get_file_state() {
    local file="$1"
    if [ -f "$file" ]; then
        stat -c "%i:%s" "$file" 2>/dev/null || echo "0:0"
    else
        echo "0:0"
    fi
}

# Load last processed state
load_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "0:0:0"  # inode:size:last_offset
    fi
}

# Save state
save_state() {
    echo "$1" > "$STATE_FILE"
}

# Parse a single email from mbox content and publish via MQTT
# Arguments: mail content (from "From " to next "From " or EOF)
publish_mail_message() {
    local mail_content="$1"

    # Extract headers
    local mail_from=""
    local subject=""
    local date_str=""
    local in_headers=1
    local body=""

    while IFS= read -r line; do
        if [ $in_headers -eq 1 ]; then
            # Empty line marks end of headers
            if [ -z "$line" ]; then
                in_headers=0
                continue
            fi

            # Parse headers (case-insensitive)
            case "${line,,}" in
                from:*)
                    mail_from="${line#*: }"
                    ;;
                subject:*)
                    subject="${line#*: }"
                    ;;
                date:*)
                    date_str="${line#*: }"
                    ;;
            esac
        else
            # Accumulate body
            if [ -n "$body" ]; then
                body="$body\n$line"
            else
                body="$line"
            fi
        fi
    done <<< "$mail_content"

    # Default values
    [ -z "$mail_from" ] && mail_from="unknown"
    [ -z "$subject" ] && subject="(no subject)"
    [ -z "$date_str" ] && date_str="$(date -R)"

    # Escape special characters for JSON
    mail_from=$(echo "$mail_from" | sed 's/\\/\\\\/g; s/"/\\"/g')
    subject=$(echo "$subject" | sed 's/\\/\\\\/g; s/"/\\"/g')
    body=$(echo -e "$body" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' '\r' | sed 's/\r/\\n/g')

    # Create JSON payload for mail message
    local payload="{\"mail_from\":\"$mail_from\",\"subject\":\"$subject\",\"body\":\"$body\",\"date\":\"$date_str\"}"

    # Publish as TEXT type with special metric name
    _mqtt_load_creds
    local topic="metrics/$_MQTT_USER/mail_message"

    if [ "${LUMENMON_TEST_MODE:-}" = "1" ]; then
        printf "  %-24s %s\n" "mail_message" "$subject"
        return 0
    fi

    mosquitto_pub \
        -h "$_MQTT_HOST" -p 8884 \
        -u "$_MQTT_USER" -P "$_MQTT_PASS" \
        --cafile "$_MQTT_CERT" --insecure \
        -t "$topic" \
        -m "$payload" 2>/dev/null && \
        echo "[mail] Forwarded: $subject" >&2 || \
        echo "[mail] WARNING: Failed to forward mail" >&2
}

# Parse mbox file and publish new messages
process_mail_file() {
    local mail_file="$1"
    local start_offset="$2"

    local file_size
    file_size=$(stat -c %s "$mail_file" 2>/dev/null || echo 0)

    # If file is smaller than our offset, it was truncated - start fresh
    if [ "$file_size" -lt "$start_offset" ]; then
        start_offset=0
    fi

    # If no new content, skip
    if [ "$file_size" -le "$start_offset" ]; then
        return 0
    fi

    # Read new content from offset
    local new_content
    new_content=$(tail -c +$((start_offset + 1)) "$mail_file" 2>/dev/null)

    if [ -z "$new_content" ]; then
        return 0
    fi

    # Parse mbox format - split on "From " at start of line
    local current_mail=""
    local mail_count=0

    while IFS= read -r line; do
        # Check if this line starts a new message (mbox "From " separator)
        if [[ "$line" =~ ^From\ .+@.+\  ]] || [[ "$line" =~ ^From\ [^\ ]+\  ]]; then
            # Process previous message if exists
            if [ -n "$current_mail" ]; then
                publish_mail_message "$current_mail"
                ((mail_count++))
            fi
            current_mail=""
        else
            if [ -n "$current_mail" ]; then
                current_mail="$current_mail"$'\n'"$line"
            else
                current_mail="$line"
            fi
        fi
    done <<< "$new_content"

    # Process last message
    if [ -n "$current_mail" ]; then
        publish_mail_message "$current_mail"
        ((mail_count++))
    fi

    echo "$file_size"  # Return new offset
}

# Main loop
main() {
    # Test mode - just report if mail exists
    if [ "${LUMENMON_TEST_MODE:-}" = "1" ]; then
        local mail_file
        if mail_file=$(find_mail_file); then
            local count
            count=$(grep -c "^From " "$mail_file" 2>/dev/null || echo 0)
            printf "  %-24s %s mails in %s\n" "mail_collector" "$count" "$mail_file"
        else
            printf "  %-24s no mail file found\n" "mail_collector"
        fi
        exit 0
    fi

    echo "[mail] Starting mail collector..."

    while true; do
        # Find mail file
        local mail_file
        if ! mail_file=$(find_mail_file); then
            sleep $CHECK_INTERVAL
            continue
        fi

        # Load state
        local state
        state=$(load_state)
        local last_inode last_size last_offset
        IFS=':' read -r last_inode last_size last_offset <<< "$state"

        # Get current file state
        local current_state
        current_state=$(get_file_state "$mail_file")
        local current_inode current_size
        IFS=':' read -r current_inode current_size <<< "$current_state"

        # Check if file changed (different inode = rotated, larger size = new mail)
        if [ "$current_inode" != "$last_inode" ]; then
            # File rotated, start fresh
            last_offset=0
            echo "[mail] Mail file rotated, resetting position"
        fi

        # Process if there's new content
        if [ "$current_size" -gt "$last_offset" ]; then
            local new_offset
            new_offset=$(process_mail_file "$mail_file" "$last_offset")
            if [ -n "$new_offset" ] && [ "$new_offset" -gt 0 ]; then
                save_state "$current_inode:$current_size:$new_offset"
            fi
        fi

        sleep $CHECK_INTERVAL
    done
}

main
