#!/usr/bin/env python3
"""
Test script to demonstrate the Lumenmon boot animation
Run this to see the animation without Docker
"""

import sys
import os

# Add console directory to path
sys.path.insert(0, 'console')

try:
    from boot_animation import show_boot_animation
    from rich.console import Console

    console = Console()

    print("Testing Lumenmon Boot Animation...")
    print("=" * 50)
    print()

    # Run the animation
    show_boot_animation()

    console.print("\n[green]✓[/green] Boot animation complete!")
    console.print("\nIn the actual TUI, this would transition to the monitoring dashboard.")

except ImportError as e:
    print(f"Error: Could not import boot animation module: {e}")
    print("Make sure you have 'rich' installed: pip install rich")
except Exception as e:
    print(f"Error running animation: {e}")