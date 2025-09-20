#!/bin/bash
# Clean data directories

echo "Cleaning data directories..."
find ../agent/data -type f ! -name '.gitkeep' -delete 2>/dev/null || true
find ../console/data -type f ! -name '.gitkeep' -delete 2>/dev/null || true
echo "Done"