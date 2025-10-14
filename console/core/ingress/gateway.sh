#!/bin/bash
# SSH ForceCommand handler that receives metric data from agents and appends to TSV files.
# Reads filename (validated as *.tsv), then appends stdin data to agent's data directory.
read -r filename
if [[ "$filename" =~ ^[a-zA-Z0-9_-]+\.tsv$ ]]; then
    cat >> "/data/agents/$USER/$filename"
fi