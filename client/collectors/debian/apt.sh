#!/bin/sh
# Debian/Ubuntu APT package metrics

# === IDENTITY ===
GROUP="debian"
COLLECTOR="apt"
PREFIX="${GROUP}_${COLLECTOR}"

# === VALIDATE ===
# Check if this is a Debian-based system
if [ ! -f /etc/debian_version ]; then
    exit 0
fi

# === COLLECT ===
# Count upgradable packages
UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable || echo "0")

# Check if reboot is required
if [ -f /var/run/reboot-required ]; then
    REBOOT_REQUIRED="yes"
else
    REBOOT_REQUIRED="no"
fi

# === OUTPUT ===
echo "${PREFIX}_updates:${UPDATES}"
echo "${PREFIX}_reboot_required:${REBOOT_REQUIRED}"