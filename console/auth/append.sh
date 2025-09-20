#!/bin/bash
read -r filename
[[ "$filename" =~ ^[a-zA-Z0-9_-]+\.tsv$ ]] && cat >> "/data/agents/$USER/$filename"