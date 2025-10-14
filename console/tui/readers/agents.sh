#!/bin/bash
# Reads agent IDs from filesystem by listing /data/agents/id_* directories.
# Provides get_agents() and count_agents() functions for dashboard display. Sourced by tui.sh.
get_agents() {
    # List all agent directories, extract basename
    for dir in /data/agents/id_*; do
        [ -d "$dir" ] && basename "$dir"
    done 2>/dev/null | sort
}

# Count agents
count_agents() {
    get_agents | wc -l
}
