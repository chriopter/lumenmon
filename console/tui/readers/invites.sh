#!/bin/bash
# Get active invites information

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
