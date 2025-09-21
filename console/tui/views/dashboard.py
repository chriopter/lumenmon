"""Dashboard view for main agent table."""

from __future__ import annotations

from typing import Iterable, List, Optional

from rich.text import Text
from textual.containers import Container, Horizontal
from textual.widgets import DataTable, Label, Static

from models import AgentSnapshot, Invite
from models.agent import STALE_AGE_SENTINEL
from models.metrics import MetricsReader

STATUS_ICONS = {
    "green": Text("●", style="green"),
    "yellow": Text("●", style="yellow"),
    "red": Text("●", style="red"),
    "dim": Text("○", style="dim"),
}

MAX_URL_DISPLAY = 40


class DashboardView(Container):
    """Main dashboard table view."""

    def __init__(self) -> None:
        super().__init__()
        self.metrics_reader = MetricsReader()

    def compose(self):  # type: ignore[override]
        """Compose the dashboard with a data table."""

        # Add clean header with small logo
        with Horizontal(id="dashboard-header"):
            yield Label("[bold bright_cyan]LUMENMON[/bold bright_cyan] System Monitor", id="header-logo")
            yield Static("", id="header-spacer")
            yield Label("[dim]Press 'h' for help[/dim]", id="header-help")

        table = DataTable(cursor_type="row")
        table.zebra_stripes = True
        table.add_column("Name/Invite", key="name", width=28)
        table.add_column("Status", key="status", width=7)
        table.add_column("CPU", key="cpu", width=20)  # Increased for sparkline
        table.add_column("Memory", key="mem", width=20)  # Increased for sparkline
        table.add_column("Disk", key="disk", width=20)  # Increased for sparkline
        table.add_column("Info", key="info", width=18)
        yield table

    def update_table(self, agents: Iterable[AgentSnapshot], invites: Iterable[Invite]) -> None:
        """Update the table with agents and invites data."""

        table = self.query_one(DataTable)

        # Preserve cursor position
        cursor_row = table.cursor_row if hasattr(table, 'cursor_row') else 0

        # Store the currently selected agent ID if any
        selected_agent_id = None
        if cursor_row < len(table.rows):
            try:
                row_data = table.get_row_at(cursor_row)
                if row_data and str(row_data[0]).startswith("id_"):
                    selected_agent_id = str(row_data[0])
            except:
                pass

        table.clear()

        self._render_agent_section(table, list(agents))
        self._render_invite_section(table, list(invites))

        # Restore cursor position
        if selected_agent_id:
            # Find the row with the same agent ID
            for i, row_key in enumerate(table.rows):
                try:
                    row_data = table.get_row_at(i)
                    if row_data and str(row_data[0]) == selected_agent_id:
                        table.cursor_coordinate = (i, 0)
                        break
                except:
                    pass
        elif cursor_row < len(table.rows):
            # Restore to the same row number if possible
            table.cursor_coordinate = (min(cursor_row, len(table.rows) - 1), 0)

    def _render_agent_section(self, table: DataTable, agents: List[AgentSnapshot]) -> None:
        table.add_row(
            Text("[bold cyan]──── CONNECTED AGENTS ────[/bold cyan]", overflow="fold"),
            Text(""), Text(""), Text(""), Text(""), Text("")
        )

        if not agents:
            table.add_row(
                Text("No agents", overflow="fold"),
                Text("⏳", style="yellow"),
                "-", "-", "-",
                Text("No agents registered", overflow="fold"),
            )
            return

        for agent in agents:
            status_icon = STATUS_ICONS.get(agent.status_color, STATUS_ICONS["dim"])

            # Generate sparklines for metrics
            cpu_display = self._create_metric_sparkline(agent.id, "generic_cpu.tsv", agent.cpu)
            mem_display = self._create_metric_sparkline(agent.id, "generic_mem.tsv", agent.memory)
            disk_display = self._create_metric_sparkline(agent.id, "generic_disk.tsv", agent.disk)

            last_update = (
                f"{int(agent.freshest_age)}s ago"
                if agent.freshest_age < STALE_AGE_SENTINEL
                else "offline"
            )

            table.add_row(
                Text(agent.id, overflow="fold"),
                status_icon,
                cpu_display,
                mem_display,
                disk_display,
                Text(last_update, overflow="fold"),
            )

    def _render_invite_section(self, table: DataTable, invites: List[Invite]) -> None:
        table.add_row(Text(""), Text(""), Text(""), Text(""), Text(""), Text(""))
        table.add_row(
            Text("[bold cyan]──── ACTIVE INVITES ────[/bold cyan]", overflow="fold"),
            Text(""), Text(""), Text(""), Text(""),
            Text("Press 'i' to create", overflow="fold"),
        )

        if not invites:
            table.add_row(
                Text("No active invites", overflow="fold"),
                Text("○", style="dim"),
                "-", "-", "-",
                Text("Press 'i' to create", overflow="fold"),
            )
            return

        for invite in invites:
            if not invite.url:
                continue

            expire_min = invite.expires // 60
            expire_sec = invite.expires % 60
            table.add_row(
                Text(invite.username, overflow="fold"),
                Text("🔑", style="cyan"),
                "-", "-", "-",
                Text(f"Expires: {expire_min}m {expire_sec}s", style="yellow", overflow="fold"),
            )
            table.add_row(
                Text(f"└─ {shorten(invite.url)}", overflow="fold"),
                Text("", overflow="fold"),
                "-", "-", "-",
                Text("[dim]Press 'c' to copy[/dim]", overflow="fold"),
            )


    def _create_metric_sparkline(self, agent_id: str, metric_file: str, current_value: Optional[float]) -> Text:
        """Create a sparkline display for a metric."""
        # Get recent history
        history = self.metrics_reader.get_history(agent_id, metric_file, points=15)

        if not history or current_value is None:
            return Text("-", style="dim")

        # Create sparkline using block characters
        blocks = "▁▂▃▄▅▆▇█"
        sparkline = ""

        if history:
            min_val = min(history)
            max_val = max(history)
            range_val = max_val - min_val if max_val != min_val else 1

            for value in history[-10:]:  # Last 10 points for compact display
                normalized = (value - min_val) / range_val
                index = int(normalized * (len(blocks) - 1))
                sparkline += blocks[index]

        # Color based on current value
        if metric_file.endswith("cpu.tsv") or metric_file.endswith("mem.tsv"):
            if current_value > 80:
                style = "bold red"
            elif current_value > 60:
                style = "yellow"
            else:
                style = "green"
        else:  # disk
            if current_value > 90:
                style = "bold red"
            elif current_value > 80:
                style = "yellow"
            else:
                style = "green"

        # Format: sparkline + current value
        return Text(f"{sparkline} {current_value:5.1f}%", style=style)


def shorten(value: str, limit: int = MAX_URL_DISPLAY) -> str:
    if len(value) <= limit:
        return value
    return f"{value[: limit - 1]}…"
