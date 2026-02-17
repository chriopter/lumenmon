#!/usr/bin/env bash
# Convenience wrapper for fast direct deploys during development.
# Delegates to ./dev/deploy-test and reads host from env/.env.

set -euo pipefail

if [ ! -f "dev/deploy-test" ]; then
    echo "Run from repo root" >&2
    exit 1
fi

TARGET="${1:-all}"
exec ./dev/deploy-test "$TARGET"
