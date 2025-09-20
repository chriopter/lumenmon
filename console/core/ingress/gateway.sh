#!/bin/bash
# Gateway script - receives filename then data
read -r filename
if [[ "$filename" =~ ^[a-zA-Z0-9_-]+\.tsv$ ]]; then
    cat >> "/data/agents/$USER/$filename"
fi