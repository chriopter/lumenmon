"""Detailed agent view with graphs and metrics."""

from __future__ import annotations

import math
import statistics
from typing import List, Optional, Tuple

import plotext as plt
from rich.text import Text
from textual.containers import Container, Horizontal, Vertical
from textual.widgets import Button, Label, ListItem, ListView, Static

from config import GRAPH_MIN_HEIGHT, GRAPH_MIN_WIDTH, GRAPH_POINTS
from models import Agent, MetricsReader


class DetailView(Container):
    """Detailed view showing agent graphs and all metrics"""

    def __init__(self, agent_id: str):
        super().__init__()
        self.agent_id = agent_id
        self.agent = Agent(agent_id)
        self.metrics = MetricsReader()
        self.all_metrics: List[str] = []

    def compose(self):
        with Vertical(id="detail_layout"):
            yield Label(f"[bold cyan]══════ Agent Details: {self.agent_id} ══════[/bold cyan]")

            with Horizontal(id="graphs_top"):
                yield Static(id="cpu_graph_large", classes="graph-panel")
                yield Static(id="mem_graph_large", classes="graph-panel")

            with Horizontal(id="graphs_bottom"):
                yield Static(id="disk_graph_large", classes="graph-panel")
                yield Static(id="custom_graph_large", classes="graph-panel")

            yield Label("[bold]Available Metrics:[/bold]", id="metrics_header")

            with Container(id="metrics_container"):
                yield ListView(id="metrics_list")

            yield Button("Back to Dashboard", id="back_button")

    def on_mount(self):
        """Initialize when mounted"""
        self.update_graphs()
        self.update_metrics_list()
        self.set_interval(2, self.update_graphs)
        self.set_interval(2, self.update_metrics_list)

    def update_metrics_list(self):
        """Update the metrics list"""
        self.all_metrics = self.metrics.get_all_metrics(self.agent_id)

        metrics_list = self.query_one("#metrics_list")
        metrics_list.clear()

        for metric in self.all_metrics:
            val, age = self.agent.read_metric(metric)
            if val is not None:
                status = "🟢" if age < 30 else "🟡" if age < 60 else "🔴"
                metrics_list.append(
                    ListItem(Label(f"{status} {metric}: {val:.2f} ({int(age)}s ago)"))
                )
            else:
                metrics_list.append(ListItem(Label(f"⚪ {metric}: No data")))

    def update_graphs(self):
        """Update all graph displays with dimensions based on terminal size"""
        width, height = self._compute_graph_size()

        cpu_history = self.metrics.get_history(self.agent_id, "generic_cpu.tsv", GRAPH_POINTS)
        self._render_graph("#cpu_graph_large", cpu_history, "CPU Usage (%)", width, height, (0, 100))

        mem_history = self.metrics.get_history(self.agent_id, "generic_mem.tsv", GRAPH_POINTS)
        self._render_graph("#mem_graph_large", mem_history, "Memory Usage (%)", width, height, (0, 100))

        disk_history = self.metrics.get_history(self.agent_id, "generic_disk.tsv", GRAPH_POINTS)
        self._render_graph("#disk_graph_large", disk_history, "Disk Usage (%)", width, height, (0, 100), no_data_message="[dim]No disk data available[/dim]")

        other_metric = next((metric for metric in self.all_metrics if not metric.startswith("generic_")), None)
        if other_metric:
            other_history = self.metrics.get_history(self.agent_id, other_metric, GRAPH_POINTS)
            title = other_metric.replace('.tsv', '').replace('_', ' ').title()
            self._render_graph("#custom_graph_large", other_history, title, width, height)
        else:
            self.query_one("#custom_graph_large").update("[dim]No additional metrics[/dim]")

    def _compute_graph_size(self) -> Tuple[int, int]:
        """Derive plot dimensions from the current terminal size"""
        app_size = getattr(self.app, "size", None)
        if app_size:
            # Split available width across two columns with padding
            width = max(GRAPH_MIN_WIDTH, (app_size.width - 10) // 2)
            usable_height = max(GRAPH_MIN_HEIGHT * 2, app_size.height - 12)
            height = max(GRAPH_MIN_HEIGHT, usable_height // 2)
        else:
            width, height = GRAPH_MIN_WIDTH * 3, GRAPH_MIN_HEIGHT * 2
        return width, height

    def _render_graph(
        self,
        selector: str,
        history: List[float],
        title: str,
        width: int,
        height: int,
        y_limits: Optional[Tuple[int, int]] = None,
        no_data_message: str = "[dim]No data available[/dim]",
    ) -> None:
        """Render a single history list into the target graph panel."""

        panel = self.query_one(selector, Static)

        if not history:
            panel.update(no_data_message)
            return

        sample_width = max(GRAPH_MIN_WIDTH, min(width - 4, 80))
        sample_height = max(GRAPH_MIN_HEIGHT, min(height - 2, 24))
        sample_count = min(len(history), max(sample_width * 2, GRAPH_MIN_WIDTH * 2))
        series = history[-sample_count:]

        plt.clf()
        clear_plot = getattr(plt, "clear_plot", None)
        if callable(clear_plot):
            clear_plot()
        clear_data = getattr(plt, "clear_data", None)
        if callable(clear_data):
            clear_data()

        try:
            plt.plotsize(sample_width, sample_height)
        except Exception:
            plt.plotsize(sample_width, GRAPH_MIN_HEIGHT)

        dark_mode = getattr(self.app, "theme", "textual-dark").endswith("dark")
        try:
            plt.theme("dark" if dark_mode else "clear")
        except Exception:
            pass

        canvas_color = "black" if dark_mode else "white"
        axis_color = "grey" if dark_mode else "black"
        line_color = "cyan" if dark_mode else "blue"
        grid_color = "grey" if dark_mode else "lightgrey"

        for setter, value in (
            (getattr(plt, "canvas_color", None), canvas_color),
            (getattr(plt, "axes_color", None), axis_color),
            (getattr(plt, "ticks_color", None), axis_color),
            (getattr(plt, "grid_color", None), grid_color),
        ):
            if callable(setter):
                try:
                    setter(value)
                except Exception:
                    pass

        if y_limits:
            plt.ylim(*y_limits)
        else:
            min_val = min(series)
            max_val = max(series)
            if math.isclose(min_val, max_val):
                delta = max(abs(min_val) * 0.1, 1.0)
                min_val -= delta
                max_val += delta
            plt.ylim(min_val, max_val)

        try:
            plt.grid(True)
        except Exception:
            pass

        plt.plot(series, color=line_color, marker="braille")

        latest = series[-1]
        minimum = min(series)
        maximum = max(series)
        average = statistics.fmean(series)

        plt.title("")
        plot_output = plt.build().rstrip()

        rendered = Text()
        rendered.append(f"{title}\n", style="bold cyan")
        rendered.append(plot_output)
        rendered.append("\n")
        rendered.append(
            f"Latest: {latest:.1f}  •  Min: {minimum:.1f}  •  Avg: {average:.1f}  •  Max: {maximum:.1f}",
            style="dim",
        )
        panel.update(rendered)
