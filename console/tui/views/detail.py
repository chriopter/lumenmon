"""Detailed agent view with graphs and metrics"""

from textual import on
from textual.widgets import Button, Static, Label, ListView, ListItem
from textual.containers import Container, Horizontal, Vertical
import plotext as plt

from models import Agent, MetricsReader


class DetailView(Container):
    """Detailed view showing agent graphs and all metrics"""

    def __init__(self, agent_id: str):
        super().__init__()
        self.agent_id = agent_id
        self.agent = Agent(agent_id)
        self.metrics = MetricsReader()
        self.all_metrics = self.metrics.get_all_metrics(agent_id)

    def compose(self):
        with Vertical():
            yield Label(f"[bold cyan]══════ Agent Details: {self.agent_id} ══════[/bold cyan]")

            # Large graphs section
            with Horizontal():
                yield Static(id="cpu_graph_large")
                yield Static(id="mem_graph_large")

            with Horizontal():
                yield Static(id="disk_graph_large")
                yield Static(id="custom_graph_large")

            # Metrics list section
            yield Label("[bold]Available Metrics:[/bold]")
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
        """Update all graph displays with larger dimensions"""
        from ..config import GRAPH_POINTS, GRAPH_WIDTH, GRAPH_HEIGHT

        # CPU Graph - Large
        cpu_history = self.metrics.get_history(self.agent_id, "generic_cpu.tsv", GRAPH_POINTS)
        if cpu_history:
            plt.clf()
            plt.theme('dark')
            plt.plot(cpu_history, marker="braille")
            plt.title("CPU Usage (%)")
            plt.ylim(0, 100)
            plt.plotsize(GRAPH_WIDTH, GRAPH_HEIGHT)
            cpu_plot = plt.build()
            self.query_one("#cpu_graph_large").update(cpu_plot)

        # Memory Graph - Large
        mem_history = self.metrics.get_history(self.agent_id, "generic_mem.tsv", GRAPH_POINTS)
        if mem_history:
            plt.clf()
            plt.theme('dark')
            plt.plot(mem_history, marker="braille")
            plt.title("Memory Usage (%)")
            plt.ylim(0, 100)
            plt.plotsize(GRAPH_WIDTH, GRAPH_HEIGHT)
            mem_plot = plt.build()
            self.query_one("#mem_graph_large").update(mem_plot)

        # Disk Graph - Large
        disk_history = self.metrics.get_history(self.agent_id, "generic_disk.tsv", GRAPH_POINTS)
        if disk_history:
            plt.clf()
            plt.theme('dark')
            plt.plot(disk_history, marker="braille")
            plt.title("Disk Usage (%)")
            plt.ylim(0, 100)
            plt.plotsize(GRAPH_WIDTH, GRAPH_HEIGHT)
            disk_plot = plt.build()
            self.query_one("#disk_graph_large").update(disk_plot)
        else:
            self.query_one("#disk_graph_large").update("[dim]No disk data available[/dim]")

        # Custom/Other metrics graph
        other_metric = None
        for metric in self.all_metrics:
            if not metric.startswith("generic_"):
                other_metric = metric
                break

        if other_metric:
            other_history = self.metrics.get_history(self.agent_id, other_metric, GRAPH_POINTS)
            if other_history:
                plt.clf()
                plt.theme('dark')
                plt.plot(other_history, marker="braille")
                plt.title(f"{other_metric.replace('.tsv', '').replace('_', ' ').title()}")
                plt.plotsize(GRAPH_WIDTH, GRAPH_HEIGHT)
                other_plot = plt.build()
                self.query_one("#custom_graph_large").update(other_plot)
            else:
                self.query_one("#custom_graph_large").update(f"[dim]No data for {other_metric}[/dim]")
        else:
            self.query_one("#custom_graph_large").update("[dim]No additional metrics[/dim]")