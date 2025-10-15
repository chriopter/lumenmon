#!/bin/bash
# Fast TSV file readers using tail for efficient last-line access.
# Reads only needed lines instead of entire files. Sourced by tui.sh.

# Read last line of a file
# Usage: read_last_line <file> <var_name>
read_last_line() {
    local file=$1
    local -n result=$2

    [ -f "$file" ] || { result=""; return 1; }

    result=$(tail -n 1 "$file" 2>/dev/null)
}

# Read last N lines using tail
# Usage: read_last_n_lines <file> <n> <array_var_name>
read_last_n_lines() {
    local file=$1
    local n=$2
    local -n arr_ref=$3

    [ -f "$file" ] || { arr_ref=(); return 1; }

    mapfile -t arr_ref < <(tail -n "$n" "$file" 2>/dev/null)
}

# Parse TSV line into fields (no awk process)
# Usage: parse_tsv_line <line> <array_var_name>
parse_tsv_line() {
    local line="$1"
    local -n fields_ref=$2

    read -ra fields_ref <<< "$line"
}

# Extract values (field 3) from array of TSV lines
# Returns space-separated string
# Usage: extract_values <lines_array_name> <output_var_name>
extract_values() {
    local -n lines_arr=$1
    local -n output=$2

    output=""
    local -a fields

    for line in "${lines_arr[@]}"; do
        read -ra fields <<< "$line"
        output+="${fields[2]:-} "
    done
}
