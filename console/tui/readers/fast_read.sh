#!/bin/bash
# Pure bash TSV file readers using circular buffers to minimize memory usage.
# Reads files sequentially, keeping only last N lines in memory instead of entire file. Sourced by tui.sh.

# Read last line of a file (sequential read, minimal memory)
# Usage: read_last_line <file> <var_name>
read_last_line() {
    local file=$1
    local -n result=$2

    [ -f "$file" ] || { result=""; return 1; }

    # Read entire file but only keep last line in memory
    local line=""
    while IFS= read -r line; do
        :  # Discard all but last
    done < "$file"

    result="$line"
}

# Read last N lines using circular buffer (only N lines in memory)
# Usage: read_last_n_lines <file> <n> <array_var_name>
read_last_n_lines() {
    local file=$1
    local n=$2
    local -n arr_ref=$3

    [ -f "$file" ] || { arr_ref=(); return 1; }

    # Circular buffer: only keep last N lines in memory
    local -a buffer
    local idx=0
    local line

    while IFS= read -r line; do
        buffer[$((idx % n))]="$line"
        ((idx++))
    done < "$file"

    # Extract lines in correct order
    arr_ref=()
    local total=$((idx < n ? idx : n))
    local start=$((idx >= n ? idx % n : 0))

    for ((i=0; i<total; i++)); do
        arr_ref+=("${buffer[$(( (start + i) % n ))]}")
    done
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
