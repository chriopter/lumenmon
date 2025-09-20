#!/bin/bash
# Ultra KISS append handler
# Reads filename from first line, then appends rest to that file
# Directory already exists from registration - no mkdir needed!

# Read the target filename
read -r filename

# Validate filename (prevent path traversal)
if [[ ! "$filename" =~ ^[a-zA-Z0-9_-]+\.tsv$ ]]; then
    exit 1
fi

# Append stdin to the file
# User permissions prevent writing outside /data/agents/$USER/
cat >> "/data/agents/$USER/$filename"