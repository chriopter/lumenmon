#!/usr/bin/env python3
# Lumenmon TUI - Ultra KISS Edition
# Read TSV from tmpfs, display metrics

import os
import sys
import time
import glob
from pathlib import Path
from datetime import datetime

from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.live import Live
from rich.text import Text
from rich import box

# Add current dir to path for boot animation
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from boot_animation import show_boot_animation

# Configuration
DATA_DIR = "/var/lib/lumenmon/hot"
REFRESH_HZ = 2

console = Console()


def get_agents():
    """Find all agents from latest directory"""
    latest_dir = f"{DATA_DIR}/latest"
    if not os.path.exists(latest_dir):
        return []
    return sorted([Path(f).stem for f in glob.glob(f"{latest_dir}/*.tsv")])


def read_metric(agent, metric_name):
    """Read specific metric from ring buffer"""
    ring_file = f"{DATA_DIR}/ring/{agent}/{metric_name}.tsv"
    if not os.path.exists(ring_file):
        return None, 999

    try:
        with open(ring_file, 'r') as f:
            lines = f.readlines()
            if lines:
                # Get last line: timestamp \t value
                parts = lines[-1].strip().split('\t')
                if len(parts) >= 2:
                    timestamp = int(parts[0])
                    value = float(parts[1])
                    age = time.time() - timestamp
                    return value, age
    except:
        pass
    return None, 999


def get_metric_history(agent, metric_name, points=60):
    """Get history for sparkline graph"""
    ring_file = f"{DATA_DIR}/ring/{agent}/{metric_name}.tsv"
    if not os.path.exists(ring_file):
        return []

    try:
        with open(ring_file, 'r') as f:
            lines = f.readlines()
            values = []
            for line in lines[-points:]:
                parts = line.strip().split('\t')
                if len(parts) >= 2:
                    values.append(float(parts[1]))
            return values
    except:
        return []


def create_sparkline(values, width=20):
    """Create mini sparkline graph"""
    if not values:
        return Text("─" * width, style="dim")

    chars = " ▁▂▃▄▅▆▇█"
    max_val = max(values) if values else 1
    min_val = min(values) if values else 0
    range_val = max_val - min_val if max_val != min_val else 1

    sparkline = ""
    for val in values[-width:]:
        normalized = (val - min_val) / range_val
        idx = int(normalized * (len(chars) - 1))
        sparkline += chars[idx]

    # Color based on last value
    last_val = values[-1] if values else 0
    if last_val > 80:
        style = "red"
    elif last_val > 50:
        style = "yellow"
    else:
        style = "green"

    return Text(sparkline, style=style)


def create_display():
    """Create the main display table"""
    # Title with timestamp
    title = f"LUMENMON CONSOLE - {datetime.now().strftime('%H:%M:%S')}"

    table = Table(title=title, box=box.ROUNDED, title_style="bold cyan")
    table.add_column("Agent", style="cyan", width=12)
    table.add_column("Status", justify="center", width=6)
    table.add_column("CPU", justify="center", width=25)
    table.add_column("Memory", justify="center", width=25)
    table.add_column("Disk", justify="center", width=25)

    agents = get_agents()

    if not agents:
        table.add_row(
            "Waiting...",
            Text("⏳", style="yellow"),
            Text("No agents connected", style="dim"),
            "",
            ""
        )
        return Panel(table, border_style="yellow")

    for agent in agents:
        # Get current values
        cpu_val, cpu_age = read_metric(agent, "cpu_usage")
        mem_val, mem_age = read_metric(agent, "mem_usage")
        disk_val, disk_age = read_metric(agent, "disk_root_usage")

        # Status based on most recent update
        min_age = min(cpu_age, mem_age, disk_age)
        if min_age < 5:
            status = Text("●", style="green")
        elif min_age < 30:
            status = Text("●", style="yellow")
        else:
            status = Text("●", style="red")

        # Get histories for sparklines
        cpu_history = get_metric_history(agent, "cpu_usage")
        mem_history = get_metric_history(agent, "mem_usage")

        # Format CPU column
        if cpu_val is not None:
            cpu_text = f"{cpu_val:5.1f}% "
            cpu_spark = create_sparkline(cpu_history, 15)
            cpu_col = Text.assemble(cpu_text, cpu_spark)
        else:
            cpu_col = Text("?", style="dim")

        # Format Memory column
        if mem_val is not None:
            mem_text = f"{mem_val:5.1f}% "
            mem_spark = create_sparkline(mem_history, 15)
            mem_col = Text.assemble(mem_text, mem_spark)
        else:
            mem_col = Text("?", style="dim")

        # Format Disk column (no sparkline, updates slowly)
        if disk_val is not None:
            disk_col = Text(f"{disk_val:5.1f}%", style="cyan")
        else:
            disk_col = Text("?", style="dim")

        table.add_row(agent, status, cpu_col, mem_col, disk_col)

    # Footer with stats
    online = sum(1 for a in agents if min(
        read_metric(a, "cpu_usage")[1],
        read_metric(a, "mem_usage")[1],
        read_metric(a, "disk_root_usage")[1]
    ) < 5)

    footer = f"Agents: {online}/{len(agents)} online | Refresh: {REFRESH_HZ}Hz | Ctrl+C to exit"

    return Panel(
        table,
        border_style="green" if online > 0 else "yellow",
        subtitle=footer,
        subtitle_align="center"
    )


def main():
    """Main TUI loop"""
    # Show boot animation unless disabled
    if os.environ.get('SKIP_ANIMATION') != '1':
        try:
            show_boot_animation()
        except:
            pass  # Continue without animation if it fails

    console.clear()

    try:
        with Live(create_display(), refresh_per_second=REFRESH_HZ, console=console) as live:
            while True:
                time.sleep(1 / REFRESH_HZ)
                live.update(create_display())
    except KeyboardInterrupt:
        console.print("\n[yellow]Shutting down TUI...[/yellow]")


if __name__ == "__main__":
    main()