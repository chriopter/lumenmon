#!/usr/bin/env python3
# Formatting utilities for TUI-style sparklines and human-readable timestamps.
# Used by metrics module to format data for HTML templates.

def generate_tui_sparkline(values):
    """Generate TUI-style sparkline using Unicode block characters."""
    if not values or len(values) == 0:
        return ''

    blocks = ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█']

    min_val = min(values)
    max_val = max(values)
    range_val = max_val - min_val if max_val - min_val > 0 else 1

    sparkline = ''
    for val in values:
        normalized = (val - min_val) / range_val
        index = int(normalized * (len(blocks) - 1))
        sparkline += blocks[index]

    return sparkline

def format_age(seconds):
    """Format age in seconds to human-readable string."""
    if seconds < 60:
        return f"{seconds}s"
    elif seconds < 3600:
        return f"{seconds // 60}m"
    elif seconds < 86400:
        return f"{seconds // 3600}h"
    else:
        return f"{seconds // 86400}d"
