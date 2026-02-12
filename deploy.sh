#!/usr/bin/env bash
# Quick dev deploy: commit, push, then update server
set -euo pipefail

SERVER="root@192.168.10.13"
SSH_KEY="$HOME/.ssh/id_ed25519"
SSH="ssh -i $SSH_KEY $SERVER"
REPO_DIR="/opt/lumenmon"
COMPOSE_DIR="\$HOME/.lumenmon/console"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info() { echo -e "${GREEN}[deploy]${NC} $*"; }
fail() { echo -e "${RED}[deploy]${NC} $*" >&2; exit 1; }

# Must run from repo root
[[ -f "deploy.sh" ]] || fail "Run from repo root"

# Check for changes to commit
if git diff --cached --quiet && git diff --quiet; then
    info "No local changes, pushing current state..."
else
    # Stage all and commit
    git add -A
    read -rp "Commit message [deploy]: " msg
    git commit -m "${msg:-deploy}"
fi

info "Pushing to origin..."
git push

info "Deploying to server..."
$SSH bash -s <<'REMOTE'
set -euo pipefail
cd /opt/lumenmon
git pull --ff-only

cd ~/.lumenmon/console
docker compose pull
docker compose up -d
REMOTE

info "Done! ✓"
