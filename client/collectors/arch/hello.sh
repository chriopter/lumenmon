#!/bin/sh
# Arch Linux hello world collector

# === IDENTITY ===
GROUP="arch"
COLLECTOR="hello"
PREFIX="${GROUP}_${COLLECTOR}"

# === VALIDATE ===
# Only run on Arch Linux
if [ ! -f /etc/arch-release ] && ! grep -qi "arch" /proc/version 2>/dev/null; then
    exit 0
fi

# === COLLECT ===
# Get Arch-specific greetings
GREETING="Hello from Arch Linux!"

# Check if running on bare metal or in container
if [ -f /.dockerenv ]; then
    RUNNING_IN="Docker on Arch"
else
    RUNNING_IN="Arch Linux"
fi

# Get pacman package count
PACKAGE_COUNT=$(pacman -Q 2>/dev/null | wc -l || echo "0")

# === OUTPUT ===
echo "${PREFIX}_greeting:${GREETING}"
echo "${PREFIX}_running_in:${RUNNING_IN}"
echo "${PREFIX}_btw:I use Arch BTW"
echo "${PREFIX}_packages:${PACKAGE_COUNT}"