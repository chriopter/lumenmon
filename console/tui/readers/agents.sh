#!/bin/bash
# List all agent IDs from filesystem

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
