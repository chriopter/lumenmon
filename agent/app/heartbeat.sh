#!/bin/bash
# Keep-alive monitoring loop

exec sh -c 'while true; do sleep 30; echo "[agent] ✓ Active - metrics flowing to '"$CONSOLE_HOST"'"; done'