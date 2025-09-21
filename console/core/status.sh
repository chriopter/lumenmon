#!/bin/sh
# Console status with comprehensive checks

# Paths
A="/data/agents"
K="/data/ssh/ssh_host_ed25519_key"
AUTH="/data/ssh/authorized_keys"
INV="/data/invites"

# Build status
S="Console:"

# SSH host key
[ -f "$K" ] && S="$S ✓key" || S="$S ✗key"

# SSH service
pgrep -f sshd >/dev/null && S="$S ✓ssh:${CONSOLE_PORT:-2345}" || S="$S ✗ssh"

# Authorized keys
[ -f "$AUTH" ] && S="$S ✓auth:$(grep -c ^ssh- "$AUTH" 2>/dev/null)" || S="$S ⚠auth:0"

# Active invites
[ -d "$INV" ] && {
    N=$(find "$INV" -type f -mmin -5 2>/dev/null | wc -l)
    [ $N -gt 0 ] && S="$S ✓inv:$N" || S="$S ○inv:0"
}

# Agents & activity
[ -d "$A" ] && {
    N=$(ls "$A" 2>/dev/null | wc -l)
    [ $N -gt 0 ] && {
        S="$S ✓agents:$N"
        # Count active (data < 60s)
        ACT=0
        for D in "$A"/*; do
            [ -d "$D" ] || continue
            H="/var/lib/lumenmon/hot/$(basename "$D")"
            [ -d "$H" ] && find "$H" -name "*.tsv" -mmin -1 2>/dev/null | grep -q . && ACT=$((ACT+1))
        done
        [ $ACT -gt 0 ] && S="$S ✓active:$ACT" || S="$S ⚠active:0"
    } || S="$S ⚠agents:0"
} || S="$S ✗agents"

echo "$S"