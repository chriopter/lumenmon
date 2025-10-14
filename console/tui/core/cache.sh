#!/bin/bash
# Mtime-based file caching to minimize disk I/O for agent metrics and history data.
# Tracks file modification times and batch-reads changed files with single awk call. Sourced by tui.sh.

# Scan for changed TSV files and return list
# Sets NEEDS_REFRESH=0 if no changes detected
scan_changed_files() {
    local changed=()
    local any_change=0

    # Check all agent metric files
    for agent_dir in /data/agents/id_*; do
        [ -d "$agent_dir" ] || continue

        for metric_file in "$agent_dir"/*.tsv; do
            [ -f "$metric_file" ] || continue

            local mtime=$(stat -c %Y "$metric_file" 2>/dev/null || echo "0")
            local cached_mtime=${FILE_MTIME[$metric_file]:-0}

            if [ "$mtime" != "$cached_mtime" ]; then
                changed+=("$metric_file")
                FILE_MTIME[$metric_file]=$mtime
                any_change=1
            fi
        done
    done

    # Return changed file list
    printf '%s\n' "${changed[@]}"
    return $any_change
}

# Update cache from changed files
# Reads all changed files in batch, updates state arrays
update_cache() {
    local -a changed_files
    mapfile -t changed_files < <(scan_changed_files)

    [ ${#changed_files[@]} -eq 0 ] && return 0

    # Batch-read all changed files with single awk call
    # Format: agent_id metric_name last_value timestamp
    awk -F'\t' '
        FNR == 1 { next }  # Skip headers if present
        {
            # Extract agent_id and metric from filename
            split(FILENAME, parts, "/")
            agent = parts[4]  # /data/agents/id_xxx/...
            metric = parts[5]
            gsub(/\.tsv$/, "", metric)

            # Store last line per file
            data[agent, metric, "value"] = $3
            data[agent, metric, "ts"] = $1
        }
        END {
            for (key in data) {
                print key "\t" data[key]
            }
        }
    ' "${changed_files[@]}" 2>/dev/null
}
