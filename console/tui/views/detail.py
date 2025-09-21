"""Detailed agent view with beautiful graphs and metrics."""

from __future__ import annotations

import math
import statistics
from collections import deque
from typing import Dict, List, Optional, Tuple

import plotext as plt
from rich.align import Align
from rich.panel import Panel
from rich.text import Text
from textual.app import ComposeResult
from textual.containers import Container, Grid, Horizontal, Vertical
from textual.reactive import reactive
from textual.widgets import Button, Label, Static

from config import GRAPH_POINTS
from models import Agent, MetricsReader


class MetricCache:
    """In-memory cache for metric data to reduce file I/O."""

    def __init__(self, max_points: int = GRAPH_POINTS * 2):
        self.max_points = max_points
        self.cache: Dict[str, deque] = {}
        self.last_update: Dict[str, float] = {}

    def update(self, metric_name: str, values: List[float]) -> List[float]:
        """Update cache with new values and return the latest data."""
        if metric_name not in self.cache:
            self.cache[metric_name] = deque(maxlen=self.max_points)

        # Only keep the latest values
        self.cache[metric_name].clear()
        self.cache[metric_name].extend(values[-self.max_points:])
        return list(self.cache[metric_name])

    def get(self, metric_name: str) -> List[float]:
        """Get cached values for a metric."""
        return list(self.cache.get(metric_name, []))


class GraphPanel(Static):
    """Enhanced graph panel with smooth rendering."""

    def __init__(self, title: str = "Graph", metric_type: str = "generic"):
        super().__init__()
        self.title = title
        self.metric_type = metric_type
        self.data: List[float] = []
        self.loading = True

    def update_data(self, data: List[float]) -> None:
        """Update the graph data and trigger re-render."""
        self.data = data
        self.loading = False
        self.refresh()

    def render(self) -> Panel:
        """Render the graph panel with plotext."""
        if self.loading:
            content = Align.center(
                Text("Loading...", style="dim italic"),
                vertical="middle"
            )
            return Panel(content, title=self.title, border_style="dim")

        if not self.data:
            content = Align.center(
                Text("No data available", style="dim"),
                vertical="middle"
            )
            return Panel(content, title=self.title, border_style="dim")

        # Get terminal size for responsive graphs
        width = self.size.width - 4 if self.size else 60
        height = self.size.height - 4 if self.size else 15

        # Ensure minimum dimensions
        width = max(40, width)
        height = max(10, height)

        # Clear and configure plotext
        plt.clf()
        plt.plotsize(width, height)

        # Apply clean theme
        plt.theme("dark")

        # Determine y-axis limits based on metric type
        if self.metric_type in ["cpu", "memory", "disk"]:
            plt.ylim(0, 100)
        else:
            # Auto-scale for other metrics
            if len(self.data) > 1:
                min_val, max_val = min(self.data), max(self.data)
                padding = (max_val - min_val) * 0.1 if max_val != min_val else 1
                plt.ylim(min_val - padding, max_val + padding)

        # Plot the data with smooth line
        x_values = list(range(len(self.data)))
        plt.plot(x_values, self.data, color="cyan", marker="braille")

        # Add grid for better readability
        plt.grid(True, True)

        # Build the plot
        plot_str = plt.build()

        # Calculate statistics
        if self.data:
            current = self.data[-1]
            minimum = min(self.data)
            maximum = max(self.data)
            average = statistics.mean(self.data)

            # Create status line with color coding
            if self.metric_type in ["cpu", "memory"]:
                if current > 80:
                    value_style = "bold red"
                elif current > 60:
                    value_style = "yellow"
                else:
                    value_style = "green"
            elif self.metric_type == "disk":
                if current > 90:
                    value_style = "bold red"
                elif current > 80:
                    value_style = "yellow"
                else:
                    value_style = "green"
            else:
                value_style = "cyan"

            stats_text = Text()
            stats_text.append("Current: ", style="dim")
            stats_text.append(f"{current:.1f}%", style=value_style)
            stats_text.append("  Min: ", style="dim")
            stats_text.append(f"{minimum:.1f}%", style="white")
            stats_text.append("  Avg: ", style="dim")
            stats_text.append(f"{average:.1f}%", style="white")
            stats_text.append("  Max: ", style="dim")
            stats_text.append(f"{maximum:.1f}%", style="white")

            # Combine plot and stats
            content = Text.from_ansi(plot_str)
            content.append("\n")
            content.append(stats_text)
        else:
            content = Text.from_ansi(plot_str)

        # Determine border style based on current value
        if self.metric_type in ["cpu", "memory", "disk"] and self.data:
            if self.data[-1] > 80:
                border_style = "red"
            elif self.data[-1] > 60:
                border_style = "yellow"
            else:
                border_style = "green"
        else:
            border_style = "cyan"

        return Panel(
            content,
            title=f"[bold]{self.title}[/bold]",
            border_style=border_style,
            padding=(0, 1)
        )


class DetailView(Container):
    """Enhanced detail view with beautiful graphs and metrics."""

    refresh_rate = reactive(0.5)  # Faster refresh for smooth updates

    def __init__(self, agent_id: str):
        super().__init__()
        self.agent_id = agent_id
        self.agent = Agent(agent_id)
        self.metrics = MetricsReader()
        self.cache = MetricCache()
        self.graphs: Dict[str, GraphPanel] = {}

    def compose(self) -> ComposeResult:
        """Compose the enhanced detail view layout."""
        with Vertical(id="detail-main"):
            # Header with agent info
            with Horizontal(id="detail-header"):
                yield Label(
                    f"[bold bright_cyan]LUMENMON[/bold bright_cyan] » Agent: {self.agent_id}",
                    id="detail-title"
                )
                yield Static("", id="detail-spacer")
                yield Label("[green]● Connected[/green]", id="detail-status")

            # Main graph grid
            with Grid(id="graphs-grid"):
                self.graphs["cpu"] = GraphPanel("CPU Usage", "cpu")
                yield self.graphs["cpu"]

                self.graphs["memory"] = GraphPanel("Memory Usage", "memory")
                yield self.graphs["memory"]

                self.graphs["disk"] = GraphPanel("Disk Usage", "disk")
                yield self.graphs["disk"]

            # Additional metrics section
            with Container(id="metrics-panel"):
                yield Label("[bold]System Information[/bold]", id="metrics-title")
                yield Static("Loading metrics...", id="metrics-info")

            # Navigation
            yield Button("← Back to Dashboard", id="back_button", variant="primary")

    def on_mount(self) -> None:
        """Start the update cycle when mounted."""
        self.update_all()
        self.set_interval(self.refresh_rate, self.update_all)

    def update_all(self) -> None:
        """Update all graphs and metrics with cached data."""
        # Update CPU graph
        cpu_history = self.metrics.get_history(self.agent_id, "generic_cpu.tsv", GRAPH_POINTS)
        if cpu_history:
            cached_cpu = self.cache.update("cpu", cpu_history)
            self.graphs["cpu"].update_data(cached_cpu)

        # Update Memory graph
        mem_history = self.metrics.get_history(self.agent_id, "generic_mem.tsv", GRAPH_POINTS)
        if mem_history:
            cached_mem = self.cache.update("memory", mem_history)
            self.graphs["memory"].update_data(cached_mem)

        # Update Disk graph
        disk_history = self.metrics.get_history(self.agent_id, "generic_disk.tsv", GRAPH_POINTS)
        if disk_history:
            cached_disk = self.cache.update("disk", disk_history)
            self.graphs["disk"].update_data(cached_disk)

        # Update system info
        self.update_system_info()

    def update_system_info(self) -> None:
        """Update the system information panel."""
        info_widget = self.query_one("#metrics-info", Static)

        # Get all available metrics
        all_metrics = self.metrics.get_all_metrics(self.agent_id)

        info_text = Text()
        info_text.append(f"Total Metrics: ", style="dim")
        info_text.append(f"{len(all_metrics)}\n", style="white")

        # Get latest values for each metric
        for metric_file in all_metrics[:5]:  # Show first 5 metrics
            metric_name = metric_file.replace(".tsv", "").replace("_", " ").title()
            history = self.metrics.get_history(self.agent_id, metric_file, points=1)

            if history:
                value = history[-1]
                info_text.append(f"{metric_name}: ", style="dim")
                info_text.append(f"{value:.2f}\n", style="cyan")

        info_widget.update(info_text)