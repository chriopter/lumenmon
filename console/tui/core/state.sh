#!/bin/bash
# Global state management for TUI including UI state, agent data, and metrics cache.
# Declares associative arrays and provides initialization and reset functions. Sourced by tui.sh.

# UI State
declare -g STATE="dashboard"           # Current view: dashboard, detail
declare -g SELECTED_ROW=0               # Currently selected row index
declare -g PREV_SELECTED_ROW=0          # Previous selected row (for differential updates)
declare -g SELECTED_AGENT=""            # Currently selected agent ID
declare -g NEEDS_REFRESH=1              # Flag to trigger data refresh
declare -g NEEDS_RENDER=1               # Flag to trigger screen render
declare -g LAST_INPUT_TIME=0            # Last time user pressed a key (for deferred refresh)

# Agent Data Cache
declare -gA AGENT_CPU                   # [agent_id] = current CPU value
declare -gA AGENT_MEM                   # [agent_id] = current memory value
declare -gA AGENT_DISK                  # [agent_id] = current disk value
declare -gA AGENT_AGE                   # [agent_id] = age string
declare -gA AGENT_STATUS                # [agent_id] = online/offline

# Metric History Cache (space-separated values)
declare -gA HISTORY_CPU                 # [agent_id] = "10 20 30 ..."
declare -gA HISTORY_MEM                 # [agent_id] = "45 50 48 ..."
declare -gA HISTORY_DISK                # [agent_id] = "70 72 71 ..."

# Pre-computed Sparklines (avoid regenerating on every render)
declare -gA SPARKLINE_CPU               # [agent_id] = "▁▂▃▄▅▆▇█"

# Temporary buffer for row building (avoids subshells)
declare -g ROW_BUFFER=""                # Temporary storage for build_agent_row output

# File mtime tracking for cache invalidation
declare -gA FILE_MTIME                  # [filepath] = last_modification_time

# Initialize state
init_state() {
    STATE="dashboard"
    SELECTED_ROW=0
    SELECTED_AGENT=""
    NEEDS_REFRESH=1
    NEEDS_RENDER=1
}

# Reset all cached data (forces full reload)
reset_cache() {
    AGENT_CPU=()
    AGENT_MEM=()
    AGENT_DISK=()
    AGENT_AGE=()
    AGENT_STATUS=()
    HISTORY_CPU=()
    HISTORY_MEM=()
    HISTORY_DISK=()
    SPARKLINE_CPU=()
    FILE_MTIME=()
    NEEDS_REFRESH=1
}
