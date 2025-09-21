#!/usr/bin/env python3
"""Lumenmon TUI - Main application."""

from __future__ import annotations

from typing import List, Optional

from textual import on
from textual.app import App, ComposeResult
from textual.containers import Container
from textual.widgets import Button, DataTable, Footer, Header

from config import REFRESH_RATE
from models import AgentSnapshot, Invite
from services import ClipboardService, MonitorService
from views import DashboardView, DetailView


class LumenmonTUI(App):
    """Interactive terminal interface for monitoring Lumenmon agents."""

    BINDINGS = [
        ("q", "quit", "Quit"),
        ("r", "refresh", "Refresh"),
        ("i", "create_invite", "Create Invite"),
        ("c", "copy_invite", "Copy Invite URL"),
        ("d", "toggle_dark", "Toggle Dark Mode"),
    ]

    CSS_PATH = "config/theme.css"

    def __init__(self) -> None:
        super().__init__()
        self.monitor = MonitorService()
        self.clipboard_service = ClipboardService()
        self.invite_urls: List[str] = []
        self._dashboard_container: Optional[Container] = None
        self._dashboard_view: Optional[DashboardView] = None
        self._detail_container: Optional[Container] = None
        self._current_agent: Optional[str] = None

    # Layout -----------------------------------------------------------------

    def compose(self) -> ComposeResult:  # type: ignore[override]
        """Compose the application layout."""

        yield Header(show_clock=True)

        dashboard_view = DashboardView()
        dashboard_container = Container(dashboard_view, id="dashboard")
        self._dashboard_container = dashboard_container
        self._dashboard_view = dashboard_view
        yield dashboard_container

        detail_container = Container(id="detail_view")
        self._detail_container = detail_container
        yield detail_container

        yield Footer()

    def on_mount(self) -> None:
        """Initialize the app after widgets are ready."""

        self.set_interval(REFRESH_RATE, self.refresh_all)
        self.refresh_all()
        self._focus_table()

    # Refresh cycle ----------------------------------------------------------

    def refresh_all(self) -> None:
        """Refresh dashboard data for agents and invites."""

        agents = self.monitor.get_agents_data()
        invites = self.monitor.get_invites_data()
        self.invite_urls = [invite.url for invite in invites if invite.url]

        if self._dashboard_view:
            self._dashboard_view.update_table(agents, invites)

    # UI helpers --------------------------------------------------------------

    def _focus_table(self) -> None:
        if not self._dashboard_view:
            return
        table = self._dashboard_view.query_one(DataTable)
        table.focus()

    def _show_detail(self, agent_id: str) -> None:
        if not self._detail_container:
            return

        self._detail_container.remove_children()
        self._detail_container.mount(DetailView(agent_id))
        self._detail_container.add_class("visible")

    def _show_dashboard(self) -> None:
        if self._detail_container:
            self._detail_container.remove_class("visible")
            self._detail_container.remove_children()
        if self._dashboard_container:
            self._dashboard_container.remove_class("hidden")

    # Event handlers ----------------------------------------------------------

    @on(DataTable.RowSelected)
    def on_row_selected(self, event: DataTable.RowSelected) -> None:
        """Open the detail view when an agent row is selected."""

        table = event.control
        if event.cursor_row >= len(table.rows):
            return

        row_data = table.get_row_at(event.cursor_row)
        if not row_data:
            return

        name = str(row_data[0]).strip()
        if not name.startswith("id_"):
            return

        self._current_agent = name
        if self._dashboard_container:
            self._dashboard_container.add_class("hidden")
        self._show_detail(name)

    @on(Button.Pressed, "#back_button")
    def back_to_dashboard(self) -> None:
        """Return to the main dashboard view."""

        self._current_agent = None
        self._show_dashboard()
        self._focus_table()

    # Actions -----------------------------------------------------------------

    def action_refresh(self) -> None:
        self.refresh_all()

    def action_copy_invite(self) -> None:
        if not self.invite_urls:
            self.notify("No active invites to copy. Press 'i' to create one.", severity="warning")
            return

        invite_url = self.invite_urls[0]
        if self.clipboard_service.copy(invite_url, app=self):
            self.notify(f"✓ Copied to clipboard!\n{invite_url}", timeout=5)
        elif self.clipboard_service.save_fallback(invite_url):
            self.notify(
                f"⚠ Could not copy to clipboard.\nSaved to: /tmp/lumenmon_invite.txt\n\n{invite_url}",
                timeout=15,
            )
        else:
            self.notify(
                f"⚠ Could not copy to clipboard.\nManually copy:\n\n{invite_url}",
                timeout=20,
            )

    def action_create_invite(self) -> None:
        invite_url = Invite.create()
        if not invite_url:
            self.notify("Failed to create invite", severity="error")
            return

        if self.clipboard_service.copy(invite_url, app=self):
            self.notify(f"✓ Invite created and copied to clipboard!\n{invite_url}", timeout=10)
        else:
            self.notify(f"Invite created:\n{invite_url}", timeout=15)

        self.refresh_all()

    def action_toggle_dark(self) -> None:
        self.theme = "textual-dark" if self.theme == "textual-light" else "textual-light"


if __name__ == "__main__":
    app = LumenmonTUI()
    app.run()
