"""Dashboard view for main agent table."""

from __future__ import annotations

from typing import Iterable, List

from rich.text import Text
from textual.containers import Container
from textual.widgets import DataTable

from models import AgentSnapshot, Invite
from models.agent import STALE_AGE_SENTINEL

STATUS_ICONS = {
    "green": Text("●", style="green"),
    "yellow": Text("●", style="yellow"),
    "red": Text("●", style="red"),
    "dim": Text("○", style="dim"),
}

MAX_URL_DISPLAY = 40


class DashboardView(Container):
    """Main dashboard table view."""

    def compose(self):  # type: ignore[override]
        """Compose the dashboard with a data table."""

        table = DataTable(cursor_type="row")
        table.zebra_stripes = True
        table.add_column("Name/Invite", key="name", width=32)
        table.add_column("Status", key="status", width=7)
        table.add_column("CPU %", key="cpu", width=7)
        table.add_column("Memory %", key="mem", width=9)
        table.add_column("Disk %", key="disk", width=7)
        table.add_column("Info", key="info", width=20)
        yield table

    def update_table(self, agents: Iterable[AgentSnapshot], invites: Iterable[Invite]) -> None:
        """Update the table with agents and invites data."""

        table = self.query_one(DataTable)
        table.clear()

        self._render_agent_section(table, list(agents))
        self._render_invite_section(table, list(invites))

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
            cpu_str = f"{agent.cpu:.1f}" if agent.cpu is not None else "-"
            mem_str = f"{agent.memory:.1f}" if agent.memory is not None else "-"
            disk_str = f"{agent.disk:.1f}" if agent.disk is not None else "-"
            last_update = (
                f"{int(agent.freshest_age)}s ago"
                if agent.freshest_age < STALE_AGE_SENTINEL
                else "offline"
            )

            table.add_row(
                Text(agent.id, overflow="fold"),
                status_icon,
                cpu_str,
                mem_str,
                disk_str,
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


def shorten(value: str, limit: int = MAX_URL_DISPLAY) -> str:
    if len(value) <= limit:
        return value
    return f"{value[: limit - 1]}…"
