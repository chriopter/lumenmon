#!/bin/bash
# SSH ForceCommand handler that receives metric data from agents and appends to TSV files.
# Reads filename (validated as *.tsv), appends stdin data, limits file to 3600 lines max.
read -r filename
if [[ "$filename" =~ ^[a-zA-Z0-9_-]+\.tsv$ ]]; then
    filepath="/data/agents/$USER/$filename"

    # Append data
    cat >> "$filepath"

    # Keep file at 3600 lines max (delete first line if over)
    line_count=$(wc -l < "$filepath" 2>/dev/null || echo 0)
    [ "$line_count" -gt 3600 ] && sed -i '1d' "$filepath"
fi

exit 0