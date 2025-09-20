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
import subprocess
import socket

# Add current dir to path for boot animation
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from boot_animation import show_boot_animation

# Configuration
DATA_DIR = "/data/agents"  # Persistent storage with per-agent directories
REFRESH_HZ = 2

console = Console()


def get_agents():
    """Find all agents from /data/agents directory"""
    if not os.path.exists(DATA_DIR):
        return []
    # List all directories in /data/agents - each is an agent
    agents = []
    for d in os.listdir(DATA_DIR):
        if os.path.isdir(os.path.join(DATA_DIR, d)):
            agents.append(d)
    return sorted(agents)


def read_metric(agent, metric_name):
    """Read specific metric from agent directory"""
    # Map old metric names to new file names
    file_map = {
        "cpu_usage": "generic_cpu.tsv",
        "mem_usage": "generic_mem.tsv",
        "disk_root_usage": "generic_disk.tsv"
    }

    metric_file = f"{DATA_DIR}/{agent}/{file_map.get(metric_name, metric_name)}"
    if not os.path.exists(metric_file):
        return None, 999

    try:
        with open(metric_file, 'r') as f:
            lines = f.readlines()
            if lines:
                # Get last line: timestamp value (space separated)
                parts = lines[-1].strip().split()
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
    # Map old metric names to new file names
    file_map = {
        "cpu_usage": "generic_cpu.tsv",
        "mem_usage": "generic_mem.tsv",
        "disk_root_usage": "generic_disk.tsv"
    }

    metric_file = f"{DATA_DIR}/{agent}/{file_map.get(metric_name, metric_name)}"
    if not os.path.exists(metric_file):
        return []

    try:
        with open(metric_file, 'r') as f:
            lines = f.readlines()
            values = []
            for line in lines[-points:]:
                parts = line.strip().split()  # Space separated now
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


def get_install_command():
    """Generate secure install command with host key"""
    try:
        # Get host IP
        hostname = socket.gethostname()
        host_ip = socket.gethostbyname(hostname)

        # Read host public key (prefer ED25519 for shorter keys)
        hostkey_path = '/etc/ssh/ssh_host_ed25519_key.pub'
        if not os.path.exists(hostkey_path):
            hostkey_path = '/etc/ssh/ssh_host_rsa_key.pub'

        with open(hostkey_path, 'r') as f:
            hostkey = f.read().strip()

        # Build command
        cmd = f'curl -sSL https://raw.githubusercontent.com/chriopter/lumenmon/main/install.sh | \\\n'
        cmd += f'  CONSOLE_HOST={host_ip} CONSOLE_HOSTKEY="{hostkey}" bash'

        return cmd
    except Exception as e:
        return f"Error generating command: {e}"

def add_agent_key():
    """Add agent public key to authorized_keys"""
    console.clear()
    console.print("\n[bold cyan]Add Agent Key[/bold cyan]\n")
    console.print("Paste the agent's public key (from agent's show-key.sh):")

    try:
        key = input("\nKey: ")

        if key and (key.startswith('ssh-rsa') or key.startswith('ssh-ed25519')):
            # Append to authorized_keys with forced command
            with open('/home/collector/.ssh/authorized_keys', 'a') as f:
                f.write(f'command="/app/ssh/receiver.sh" {key}\n')
            console.print("\n[green]✓ Agent key added successfully![/green]")
            console.print("Agent can now connect to this console.")
        else:
            console.print("\n[red]Invalid key format. Expected ssh-rsa or ssh-ed25519...[/red]")
    except Exception as e:
        console.print(f"\n[red]Error: {e}[/red]")

    console.print("\nPress Enter to continue...")
    input()


def main():
    """Main TUI loop"""
    # Show boot animation unless disabled
    if os.environ.get('SKIP_ANIMATION') != '1':
        try:
            show_boot_animation()
        except:
            pass  # Continue without animation if it fails

    console.clear()

    # Instructions
    console.print("[dim]Press Ctrl+C for menu[/dim]\n")

    # Simple main loop without complex terminal handling
    try:
        with Live(create_display(), refresh_per_second=REFRESH_HZ, console=console) as live:
            while True:
                time.sleep(1 / REFRESH_HZ)
                live.update(create_display())
    except KeyboardInterrupt:
        # When user hits Ctrl+C, show menu
        show_menu()

def show_menu():
    """Show main menu when Ctrl+C is pressed"""
    console.clear()
    console.print("\n[bold cyan]Lumenmon Console Menu[/bold cyan]\n")
    console.print("[1] Show secure install command")
    console.print("[2] Add agent key")
    console.print("[3] Return to dashboard")
    console.print("[4] Exit\n")

    try:
        choice = input("Enter choice (1-4): ")

        if choice == '1':
            console.clear()
            console.print("\n[bold cyan]Secure Install Command[/bold cyan]\n")
            console.print("Run this on the agent machine:\n")
            console.print(f"[yellow]{get_install_command()}[/yellow]")
            console.print("\nPress Enter to continue...")
            input()
            main()  # Return to dashboard
        elif choice == '2':
            add_agent_key()
            main()  # Return to dashboard
        elif choice == '3':
            main()  # Return to dashboard
        elif choice == '4':
            console.print("\n[yellow]Goodbye![/yellow]\n")
            sys.exit(0)
        else:
            console.print("[red]Invalid choice[/red]")
            show_menu()
    except (EOFError, KeyboardInterrupt):
        console.print("\n[yellow]Goodbye![/yellow]\n")
        sys.exit(0)


if __name__ == "__main__":
    main()