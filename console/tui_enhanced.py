#!/usr/bin/env python3
"""
Lumenmon Console TUI - Enhanced multi-metric display
Displays all metrics from agents in a comprehensive dashboard
"""

import os
import time
import glob
from datetime import datetime
from collections import deque, defaultdict
from pathlib import Path

from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.layout import Layout
from rich.live import Live
from rich.align import Align
from rich.text import Text
from rich import box
from rich.columns import Columns
from rich.progress import Progress, BarColumn, TextColumn

# Configuration
HOT_DIR = "/var/lib/lumenmon/hot"
LATEST_DIR = f"{HOT_DIR}/latest"
RING_DIR = f"{HOT_DIR}/ring"
REFRESH_HZ = 2  # 2Hz refresh rate for balanced updates
GRAPH_WIDTH = 60  # Width for graphs
GRAPH_HEIGHT = 8  # Height for graphs

console = Console()


class AgentMonitor:
    """Monitor for a single agent with all metrics"""

    def __init__(self, agent_id):
        self.agent_id = agent_id
        self.last_seen = 0

        # CPU metrics
        self.cpu_history = deque(maxlen=GRAPH_WIDTH)
        self.current_cpu = 0
        self.load_1min = 0
        self.load_5min = 0
        self.load_15min = 0

        # Memory metrics
        self.mem_history = deque(maxlen=GRAPH_WIDTH)
        self.mem_percent = 0
        self.mem_total_mb = 0
        self.mem_available_mb = 0
        self.swap_percent = 0

        # Disk metrics
        self.disk_usage = {}  # mount -> percent

        # Network metrics
        self.net_rx_mbps = 0
        self.net_tx_mbps = 0
        self.net_connected = False
        self.net_latency = 0

        # Process metrics
        self.proc_total = 0
        self.proc_running = 0
        self.proc_sleeping = 0
        self.proc_zombie = 0

        # System info
        self.sys_os = "unknown"
        self.sys_kernel = "unknown"
        self.sys_uptime_days = 0
        self.sys_container = "none"

    def update(self):
        """Read latest data from TSV files"""
        # Read all metrics from ring buffers for this agent
        ring_path = f"{RING_DIR}/{self.agent_id}"

        if os.path.exists(ring_path):
            # CPU history
            cpu_file = f"{ring_path}/cpu_usage.tsv"
            if os.path.exists(cpu_file):
                try:
                    with open(cpu_file, 'r') as f:
                        lines = f.readlines()
                        recent = lines[-GRAPH_WIDTH:] if len(lines) > GRAPH_WIDTH else lines
                        self.cpu_history.clear()
                        for line in recent:
                            parts = line.strip().split('\t')
                            if len(parts) >= 5:
                                self.cpu_history.append(float(parts[4]))
                                self.last_seen = int(parts[0])
                        if self.cpu_history:
                            self.current_cpu = self.cpu_history[-1]
                except:
                    pass

            # Memory history
            mem_file = f"{ring_path}/mem_usage_percent.tsv"
            if os.path.exists(mem_file):
                try:
                    with open(mem_file, 'r') as f:
                        lines = f.readlines()
                        recent = lines[-GRAPH_WIDTH:] if len(lines) > GRAPH_WIDTH else lines
                        self.mem_history.clear()
                        for line in recent:
                            parts = line.strip().split('\t')
                            if len(parts) >= 5:
                                self.mem_history.append(float(parts[4]))
                        if self.mem_history:
                            self.mem_percent = self.mem_history[-1]
                except:
                    pass

            # Read other latest metrics
            self.read_latest_metrics(ring_path)

        # Also read from latest file for current values
        latest_file = f"{LATEST_DIR}/{self.agent_id}.tsv"
        if os.path.exists(latest_file):
            try:
                with open(latest_file, 'r') as f:
                    line = f.readline().strip()
                    if line:
                        parts = line.split('\t')
                        if len(parts) >= 3:
                            self.last_seen = int(parts[0])
            except:
                pass

    def read_latest_metrics(self, ring_path):
        """Read the latest value from each metric file"""
        for metric_file in glob.glob(f"{ring_path}/*.tsv"):
            metric_name = Path(metric_file).stem
            try:
                with open(metric_file, 'r') as f:
                    # Get last line
                    lines = f.readlines()
                    if lines:
                        last_line = lines[-1].strip()
                        parts = last_line.split('\t')
                        if len(parts) >= 5:
                            value = parts[4]

                            # Parse based on metric name
                            if metric_name == "load_1min":
                                self.load_1min = float(value)
                            elif metric_name == "load_5min":
                                self.load_5min = float(value)
                            elif metric_name == "load_15min":
                                self.load_15min = float(value)
                            elif metric_name == "mem_total_mb":
                                self.mem_total_mb = int(value)
                            elif metric_name == "mem_available_mb":
                                self.mem_available_mb = int(value)
                            elif metric_name == "swap_usage_percent":
                                self.swap_percent = float(value)
                            elif metric_name.startswith("disk_") and metric_name.endswith("_usage_percent"):
                                mount = metric_name[5:-14]  # Extract mount name
                                self.disk_usage[mount] = float(value)
                            elif metric_name == "net_rx_mbps":
                                self.net_rx_mbps = float(value)
                            elif metric_name == "net_tx_mbps":
                                self.net_tx_mbps = float(value)
                            elif metric_name == "net_connected":
                                self.net_connected = int(value) == 1
                            elif metric_name == "net_latency_ms":
                                self.net_latency = float(value)
                            elif metric_name == "proc_total":
                                self.proc_total = int(value)
                            elif metric_name == "proc_running":
                                self.proc_running = int(value)
                            elif metric_name == "proc_sleeping":
                                self.proc_sleeping = int(value)
                            elif metric_name == "proc_zombie":
                                self.proc_zombie = int(value)
                            elif metric_name == "sys_os":
                                self.sys_os = value
                            elif metric_name == "sys_kernel":
                                self.sys_kernel = value
                            elif metric_name == "sys_uptime_days":
                                self.sys_uptime_days = int(value)
                            elif metric_name == "sys_container":
                                self.sys_container = value
            except:
                pass

    def is_online(self):
        """Check if agent is online (data less than 5 seconds old)"""
        return (time.time() - self.last_seen) < 5

    def create_mini_graph(self, data, max_val=100, width=20, height=4):
        """Create a compact ASCII graph"""
        if not data:
            return ["No data"]

        lines = []
        chars = " ▁▂▃▄▅▆▇█"

        # Create graph
        for y in range(height, 0, -1):
            line = ""
            threshold = (y / height) * max_val

            for value in list(data)[-width:]:
                if value >= threshold:
                    line += "█"
                else:
                    line += " "

            # Add Y-axis label for top and bottom
            if y == height:
                label = f"{max_val:3.0f}%"
            elif y == 1:
                label = "  0%"
            else:
                label = "    "

            lines.append(label + "│" + line)

        # Add X-axis
        lines.append("    └" + "─" * width)

        return lines


class LumenmonConsole:
    """Main Console TUI application"""

    def __init__(self):
        self.agents = {}
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

    def discover_agents(self):
        """Discover agents from latest directory"""
        for tsv_file in glob.glob(f"{LATEST_DIR}/*.tsv"):
            agent_id = Path(tsv_file).stem
            if agent_id not in self.agents:
                self.agents[agent_id] = AgentMonitor(agent_id)

    def update_agents(self):
        """Update all agent data"""
        for agent in self.agents.values():
            agent.update()

    def create_header(self):
        """Create header panel"""
        title = Text("LUMENMON CONSOLE", style="bold cyan")
        subtitle = Text("Comprehensive System Monitoring Dashboard", style="dim")
        return Panel(Align.center(title + "\n" + subtitle), box=box.DOUBLE, style="cyan")

    def create_agent_panel(self, agent):
        """Create comprehensive panel for a single agent"""
        status = "🟢" if agent.is_online() else "🔴"

        # Create sub-panels for different metrics
        panels = []

        # System Info Panel
        sys_info = Table(show_header=False, box=None, padding=0)
        sys_info.add_column("Key", style="dim")
        sys_info.add_column("Value")
        sys_info.add_row("OS:", agent.sys_os)
        sys_info.add_row("Kernel:", agent.sys_kernel[:20])
        sys_info.add_row("Uptime:", f"{agent.sys_uptime_days}d")
        sys_info.add_row("Container:", agent.sys_container)

        # CPU Panel
        cpu_graph = agent.create_mini_graph(agent.cpu_history, 100, 25, 4)
        cpu_text = Text(f"CPU: {agent.current_cpu:.1f}%",
                       style="green" if agent.current_cpu < 50 else "yellow" if agent.current_cpu < 80 else "red")
        cpu_content = cpu_text.plain + "\n" + "\n".join(cpu_graph)
        cpu_content += f"\nLoad: {agent.load_1min:.2f} {agent.load_5min:.2f} {agent.load_15min:.2f}"

        # Memory Panel
        mem_graph = agent.create_mini_graph(agent.mem_history, 100, 25, 4)
        mem_text = Text(f"Memory: {agent.mem_percent:.1f}%",
                       style="green" if agent.mem_percent < 50 else "yellow" if agent.mem_percent < 80 else "red")
        mem_content = mem_text.plain + "\n" + "\n".join(mem_graph)
        if agent.mem_total_mb > 0:
            mem_content += f"\n{agent.mem_available_mb}MB / {agent.mem_total_mb}MB available"
        if agent.swap_percent > 0:
            mem_content += f"\nSwap: {agent.swap_percent:.1f}%"

        # Network Panel
        net_status = "✓" if agent.net_connected else "✗"
        net_content = f"Network {net_status}\n"
        net_content += f"↓ {agent.net_rx_mbps:.2f} Mbps\n"
        net_content += f"↑ {agent.net_tx_mbps:.2f} Mbps"
        if agent.net_latency > 0:
            net_content += f"\nPing: {agent.net_latency:.1f}ms"

        # Disk Panel
        disk_content = "Disk Usage:\n"
        for mount, usage in sorted(agent.disk_usage.items())[:3]:  # Show top 3
            disk_content += f"{mount}: {usage:.1f}%\n"

        # Process Panel
        proc_content = f"Processes: {agent.proc_total}\n"
        proc_content += f"R:{agent.proc_running} S:{agent.proc_sleeping} Z:{agent.proc_zombie}"

        # Combine into columns
        col1 = Panel(sys_info, title="System", box=box.ROUNDED)
        col2 = Panel(cpu_content, title="CPU", box=box.ROUNDED)
        col3 = Panel(mem_content, title="Memory", box=box.ROUNDED)
        col4 = Panel(net_content, title="Network", box=box.ROUNDED)
        col5 = Panel(disk_content, title="Disk", box=box.ROUNDED)
        col6 = Panel(proc_content, title="Processes", box=box.ROUNDED)

        # Create layout for agent
        agent_layout = Layout()
        agent_layout.split_row(
            Layout(col1, size=20),
            Layout(col2, size=35),
            Layout(col3, size=35),
            Layout(col4, size=20),
            Layout(col5, size=20),
            Layout(col6, size=20)
        )

        return Panel(
            agent_layout,
            title=f"{status} {agent.agent_id}",
            box=box.DOUBLE,
            border_style="green" if agent.is_online() else "red"
        )

    def create_body(self):
        """Create body with all agent panels"""
        if not self.agents:
            return Panel(
                Align.center(Text("Waiting for agents to connect...", style="dim")),
                box=box.ROUNDED
            )

        # Create panels for each agent
        panels = []
        for agent_id, agent in sorted(self.agents.items()):
            panels.append(self.create_agent_panel(agent))

        # Stack panels vertically
        if len(panels) == 1:
            return panels[0]
        else:
            body_layout = Layout()
            rows = [Layout(panel) for panel in panels]
            body_layout.split_column(*rows)
            return body_layout

    def create_footer(self):
        """Create footer with stats"""
        online = sum(1 for a in self.agents.values() if a.is_online())
        total = len(self.agents)
        timestamp = datetime.now().strftime("%H:%M:%S")

        text = f"Agents: {online}/{total} online | Refresh: {REFRESH_HZ}Hz | Time: {timestamp} | Press Ctrl+C to exit"
        return Text(text, style="dim", justify="center")

    def update(self):
        """Update the entire TUI"""
        self.discover_agents()
        self.update_agents()

        self.layout["header"].update(self.create_header())
        self.layout["body"].update(self.create_body())
        self.layout["footer"].update(self.create_footer())

        return self.layout


def main():
    """Main TUI loop"""
    tui = LumenmonConsole()

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
        console.print("\n[yellow]Shutting down Lumenmon Console...")
    except Exception as e:
        console.print(f"[red]Error: {e}")
        raise


if __name__ == "__main__":
    main()