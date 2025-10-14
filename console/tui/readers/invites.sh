#!/bin/bash
# Reads active invite information from /tmp/.invite_* files for dashboard display.
# Provides get_invite_count() and get_invites() functions. Sourced by tui.sh.
# Count active invites
get_invite_count() {
    ls -1 /tmp/.invite_* 2>/dev/null | wc -l
}

# Get list of invite usernames
get_invites() {
    for file in /tmp/.invite_*; do
        [ -f "$file" ] && basename "$file" | sed 's/^\.invite_//'
    done 2>/dev/null
}
