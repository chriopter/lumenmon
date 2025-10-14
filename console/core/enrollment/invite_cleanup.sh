#!/bin/bash
# Deletes temporary registration users that are older than 5 minutes.
# Scans all reg_* users and removes those with expired timestamps.
CUTOFF=$(($(date +%s%3N) - 300000))
for user in $(getent passwd | grep ^reg_ | cut -d: -f1); do
    TIMESTAMP=${user#reg_}
    if [ "$TIMESTAMP" -lt "$CUTOFF" ] 2>/dev/null; then
        userdel -r "$user" 2>/dev/null
        rm -f "/tmp/.invite_${user}" 2>/dev/null
    fi
done