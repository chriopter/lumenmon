#!/usr/bin/env python3
# Formatting utilities - imported by unified_server.py.
# Provides sparkline generation and age formatting for dashboard display.

def generate_tui_sparkline(values, max_chars=8, global_max=None):
    """Generate TUI-style sparkline using Unicode block characters.

    If global_max is provided, scales to 0-global_max range (for comparing across hosts).
    Otherwise scales to local min-max range.
    """
    if not values or len(values) == 0:
        return ''

    # Limit to last N characters
    values = values[-max_chars:]

    blocks = ['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█']

    if global_max is not None:
        # Scale to 0-global_max for cross-host comparison
        min_val = 0
        max_val = global_max if global_max > 0 else 1
    else:
        # Scale to local min-max (original behavior)
        min_val = min(values)
        max_val = max(values)

    range_val = max_val - min_val if max_val - min_val > 0 else 1

    sparkline = ''
    for val in values:
        normalized = (val - min_val) / range_val
        # Clamp to valid range
        normalized = max(0, min(1, normalized))
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
