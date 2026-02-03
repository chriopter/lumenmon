#!/bin/bash
# Reads local mail from /var/mail/root and forwards via MQTT.
# Only runs if mail spool exists. Checks every 5 minutes.

CHECK_INTERVAL=300  # 5 minutes

source "$LUMENMON_HOME/core/mqtt/publish.sh"

# Find mail spool file
MAIL_FILE=""
for loc in /var/mail/root /var/spool/mail/root; do
    [ -f "$loc" ] && [ -r "$loc" ] && MAIL_FILE="$loc" && break
done

# Exit if no mail spool - this collector not needed
if [ -z "$MAIL_FILE" ]; then
    [ "${LUMENMON_TEST_MODE:-}" = "1" ] && printf "  %-24s (no spool)\n" "mail_collector"
    exit 0
fi

STATE_FILE="$LUMENMON_DATA/mail_offset"

# Test mode - just show count
if [ "${LUMENMON_TEST_MODE:-}" = "1" ]; then
    count=$(grep -c "^From " "$MAIL_FILE" 2>/dev/null || echo 0)
    printf "  %-24s %s mails\n" "mail_collector" "$count"
    exit 0
fi

# Publish single mail via MQTT
publish_mail() {
    local content="$1"
    local mail_from="" subject="" body="" in_headers=1

    while IFS= read -r line; do
        if [ $in_headers -eq 1 ]; then
            [ -z "$line" ] && in_headers=0 && continue
            case "${line,,}" in
                from:*) mail_from="${line#*: }" ;;
                subject:*) subject="${line#*: }" ;;
            esac
        else
            body="${body:+$body\n}$line"
        fi
    done <<< "$content"

    [ -z "$mail_from" ] && mail_from="unknown"
    [ -z "$subject" ] && subject="(no subject)"

    # Escape for JSON
    mail_from=$(echo "$mail_from" | sed 's/\\/\\\\/g; s/"/\\"/g')
    subject=$(echo "$subject" | sed 's/\\/\\\\/g; s/"/\\"/g')
    body=$(echo -e "$body" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | tr '\n' '\r' | sed 's/\r/\\n/g')

    _mqtt_load_creds
    mosquitto_pub -h "$_MQTT_HOST" -p 8884 -u "$_MQTT_USER" -P "$_MQTT_PASS" \
        --cafile "$_MQTT_CERT" --insecure \
        -t "metrics/$_MQTT_USER/mail_message" \
        -m "{\"mail_from\":\"$mail_from\",\"subject\":\"$subject\",\"body\":\"$body\"}" 2>/dev/null && \
        echo "[mail] $subject" >&2
}

# Main loop
while true; do
    size=$(stat -c %s "$MAIL_FILE" 2>/dev/null || echo 0)
    offset=$(cat "$STATE_FILE" 2>/dev/null || echo 0)

    # Reset if file truncated
    [ "$size" -lt "$offset" ] && offset=0

    # Process new mail
    if [ "$size" -gt "$offset" ]; then
        current=""
        while IFS= read -r line; do
            if [[ "$line" =~ ^From\ .+\  ]]; then
                [ -n "$current" ] && publish_mail "$current"
                current=""
            else
                current="${current:+$current
}$line"
            fi
        done < <(tail -c +$((offset + 1)) "$MAIL_FILE")
        [ -n "$current" ] && publish_mail "$current"
        echo "$size" > "$STATE_FILE"
    fi

    sleep $CHECK_INTERVAL
done
