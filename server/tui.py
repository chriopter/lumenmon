#!/usr/bin/env python3
"""
Lumenmon v3 TUI - Real-time monitoring with graphs
Simple, KISS design using TSV files from tmpfs
"""

import os
import time
import glob
from datetime import datetime
from collections import deque
from pathlib import Path

from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.layout import Layout
from rich.live import Live
from rich.align import Align
from rich.text import Text
from rich import box

# Configuration
HOT_DIR = "/var/lib/lumenmon/hot"
LATEST_DIR = f"{HOT_DIR}/latest"
RING_DIR = f"{HOT_DIR}/ring"
REFRESH_HZ = 5  # 5Hz refresh rate to see more frequent updates
GRAPH_WIDTH = 100  # Show 10 seconds of 10Hz data
GRAPH_HEIGHT = 15  # Taller graph for better visibility

console = Console()


class ClientMonitor:
    """Monitor for a single client"""

    def __init__(self, client_id):
        self.client_id = client_id
        self.cpu_history = deque(maxlen=GRAPH_WIDTH)  # Will hold 100 samples (10 seconds at 10Hz)
        self.last_seen = 0
        self.current_cpu = 0

    def update(self):
        """Read latest data from TSV files"""
        # Read latest CPU value
        latest_file = f"{LATEST_DIR}/{self.client_id}.tsv"
        if os.path.exists(latest_file):
            try:
                with open(latest_file, 'r') as f:
                    line = f.readline().strip()
                    if line:
                        parts = line.split('\t')
                        if len(parts) >= 5:
                            self.last_seen = int(parts[0])
                            self.current_cpu = float(parts[4])

                # Read CPU history from ring buffer
                ring_file = f"{RING_DIR}/{self.client_id}/cpu_usage.tsv"
                if os.path.exists(ring_file):
                    with open(ring_file, 'r') as f:
                        lines = f.readlines()
                        # Get last GRAPH_WIDTH samples
                        recent = lines[-GRAPH_WIDTH:] if len(lines) > GRAPH_WIDTH else lines
                        self.cpu_history.clear()
                        for line in recent:
                            parts = line.strip().split('\t')
                            if len(parts) >= 5:
                                self.cpu_history.append(float(parts[4]))
            except Exception:
                pass  # Ignore read errors (file being written)

    def is_online(self):
        """Check if client is online (data less than 5 seconds old)"""
        return (time.time() - self.last_seen) < 5

    def create_sparkline(self, width=GRAPH_WIDTH, height=8):
        """Create a sparkline graph of CPU usage"""
        if not self.cpu_history:
            return Text("No data", style="dim")

        # Create ASCII graph
        chars = " ▁▂▃▄▅▆▇█"
        graph = []

        for value in self.cpu_history:
            # Map 0-100% to character index
            idx = int((value / 100) * (len(chars) - 1))
            idx = min(max(idx, 0), len(chars) - 1)
            graph.append(chars[idx])

        return Text("".join(graph), style="cyan")

    def create_bar_graph(self, width=GRAPH_WIDTH, height=GRAPH_HEIGHT):
        """Create a bar graph of CPU usage with dynamic scaling"""
        if not self.cpu_history:
            return ["No data available"]

        lines = []

        # Dynamic scaling: use actual max value from history (with 10% padding)
        actual_max = max(self.cpu_history) if self.cpu_history else 1
        # Add 10% padding, but at least show up to 10%
        max_val = max(actual_max * 1.1, 10)

        # Create graph from top to bottom
        for y in range(height, 0, -1):
            line = ""
            threshold = (y / height) * max_val

            for value in self.cpu_history:
                if value >= threshold:
                    line += "█"
                else:
                    line += " "

            # Add Y-axis label with dynamic scale
            label = f"{threshold:5.1f}% "

            # Color based on actual CPU percentage
            if threshold > 80:
                color = "red"
            elif threshold > 50:
                color = "yellow"
            else:
                color = "green"

            lines.append(Text(label, style="dim") + Text(line, style=color))

        # Add X-axis with proper 10Hz labeling
        lines.append(Text("       " + "─" * len(self.cpu_history), style="dim"))
        lines.append(Text(f"       Last {len(self.cpu_history)} samples @ 10Hz ({len(self.cpu_history)/10:.1f}s)", style="dim"))
        lines.append(Text(f"       Max: {actual_max:.1f}% | Scale: 0-{max_val:.1f}%", style="cyan"))

        return lines


class LumenmonTUI:
    """Main TUI application"""

    def __init__(self):
        self.clients = {}
        self.layout = self.create_layout()

    def create_layout(self):
        """Create the TUI layout"""
        layout = Layout()
        layout.split_column(
            Layout(name="header", size=3),
            Layout(name="body"),
            Layout(name="footer", size=1)
        )
        return layout

    def discover_clients(self):
        """Discover clients from latest directory"""
        for env_file in glob.glob(f"{LATEST_DIR}/*.env"):
            client_id = Path(env_file).stem
            if client_id not in self.clients:
                self.clients[client_id] = ClientMonitor(client_id)

    def update_clients(self):
        """Update all client data"""
        for client in self.clients.values():
            client.update()

    def create_header(self):
        """Create header panel"""
        title = Text("LUMENMON v3", style="bold cyan")
        subtitle = Text("Real-time System Monitor | SSH + TSV + Python", style="dim")
        return Panel(Align.center(title + "\n" + subtitle), box=box.DOUBLE, style="cyan")

    def create_client_panel(self, client):
        """Create panel for a single client"""
        status = "🟢" if client.is_online() else "🔴"

        # Calculate average CPU for title
        avg_cpu = sum(client.cpu_history) / len(client.cpu_history) if client.cpu_history else 0
        max_cpu = max(client.cpu_history) if client.cpu_history else 0

        title = f"{status} {client.client_id} | Current: {client.current_cpu:.1f}% | Avg: {avg_cpu:.1f}% | Peak: {max_cpu:.1f}%"

        # Create graph
        graph_lines = client.create_bar_graph()

        # Combine into panel content
        content = "\n".join(str(line) for line in graph_lines)

        return Panel(
            content,
            title=title,
            box=box.ROUNDED,
            border_style="green" if client.is_online() else "red"
        )

    def create_body(self):
        """Create body with all client panels"""
        if not self.clients:
            return Panel(
                Align.center(Text("Waiting for clients...", style="dim")),
                box=box.ROUNDED
            )

        # Create a grid of client panels
        panels = []
        for client_id, client in sorted(self.clients.items()):
            panels.append(self.create_client_panel(client))

        # Stack panels vertically (you could make this a grid for multiple clients)
        if len(panels) == 1:
            return panels[0]
        else:
            # Create sub-layout for multiple clients
            body_layout = Layout()
            rows = []
            for panel in panels:
                rows.append(Layout(panel))

            body_layout.split_column(*rows)
            return body_layout

    def create_footer(self):
        """Create footer with stats"""
        online = sum(1 for c in self.clients.values() if c.is_online())
        total = len(self.clients)
        timestamp = datetime.now().strftime("%H:%M:%S")

        text = f"Clients: {online}/{total} online | Display: {REFRESH_HZ}Hz | Sampling: 10Hz | Graph: {GRAPH_WIDTH} samples | Time: {timestamp} | Press Ctrl+C to exit"
        return Text(text, style="dim", justify="center")

    def update(self):
        """Update the entire TUI"""
        self.discover_clients()
        self.update_clients()

        self.layout["header"].update(self.create_header())
        self.layout["body"].update(self.create_body())
        self.layout["footer"].update(self.create_footer())

        return self.layout


def main():
    """Main TUI loop"""
    tui = LumenmonTUI()

    # Check if running in Docker or with proper paths
    if not os.path.exists(HOT_DIR):
        console.print("[red]Error: Hot directory not found at " + HOT_DIR)
        console.print("[yellow]Creating directory structure...")
        os.makedirs(LATEST_DIR, exist_ok=True)
        os.makedirs(RING_DIR, exist_ok=True)

    try:
        # Use context manager for alternate screen
        with console.screen(style="bold white on black") as screen:
            while True:
                # Update and render
                screen.update(Panel(tui.update(), border_style="green"))
                time.sleep(1 / REFRESH_HZ)
    except KeyboardInterrupt:
        console.print("\n[yellow]Shutting down...")
    except Exception as e:
        console.print(f"[red]Error: {e}")
        raise


if __name__ == "__main__":
    main()