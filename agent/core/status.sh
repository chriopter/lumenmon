#!/bin/sh
# Agent status with comprehensive checks

# Paths
CFG="/data/config/console"
KEY="/home/metrics/.ssh/id_ed25519"
RSA="/home/metrics/.ssh/id_rsa"

# Build status line
S="Agent:"

# SSH key check
[ -f "$KEY" ] && { S="$S ✓key"; K="$KEY"; } || \
[ -f "$RSA" ] && { S="$S ✓key(rsa)"; K="$RSA"; } || \
{ echo "$S ✗key"; exit; }

# Agent ID
[ -f "$K.username" ] && S="$S ✓id:$(cat "$K.username" | cut -c4-10)" || S="$S ✗id"

# Console config
[ -f "$CFG" ] || { echo "$S ✗cfg"; exit; }
. "$CFG"
S="$S ✓cfg:$CONSOLE_HOST:$CONSOLE_PORT"

# Network test
nc -zw1 "$CONSOLE_HOST" "$CONSOLE_PORT" 2>/dev/null && S="$S ✓net" || S="$S ✗net"

# Host fingerprint
grep -q "$CONSOLE_HOST" ~/.ssh/known_hosts 2>/dev/null && S="$S ✓host" || S="$S ⚠host"

# SSH connection & metrics
if pgrep -f "ssh.*collector" >/dev/null; then
    S="$S ✓ssh"
    [ -f /tmp/last_metric ] && {
        T=$(tail -1 /tmp/last_metric | cut -d' ' -f1 | cut -dT -f2 | cut -d. -f1)
        S="$S ✓data:$T"
    } || S="$S ⚠data"
else
    S="$S ✗ssh"
fi

echo "$S"